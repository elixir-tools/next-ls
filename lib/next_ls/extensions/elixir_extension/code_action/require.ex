defmodule NextLS.ElixirExtension.CodeAction.Require do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ASTHelpers

  @one_indentation_level "  "
  @spec new(diagnostic :: Diagnostic.t(), [text :: String.t()], uri :: String.t()) :: [CodeAction.t()]
  def new(%Diagnostic{} = diagnostic, text, uri) do
    range = diagnostic.range

    with {:ok, require_module} <- get_edit(diagnostic.message),
         {:ok, ast} <- parse_ast(text),
         {:ok, defm} <- ASTHelpers.get_surrounding_module(ast, range.start),
         indentation <- get_indent(text, defm),
         nearest <- find_nearest_node_for_require(defm),
         range <- get_edit_range(nearest) do
      [
        %CodeAction{
          title: "Add missing require for #{require_module}",
          diagnostics: [diagnostic],
          edit: %WorkspaceEdit{
            changes: %{
              uri => [
                %TextEdit{
                  new_text: indentation <> "require #{require_module}\n",
                  range: range
                }
              ]
            }
          }
        }
      ]
    else
      _error ->
        []
    end
  end

  defp parse_ast(text) do
    text
    |> Enum.join("\n")
    |> Spitfire.parse()
  end

  @module_name ~r/require\s+([^\s]+)\s+before/
  defp get_edit(message) do
    case Regex.run(@module_name, message) do
      [_, module] -> {:ok, module}
      _ -> {:error, "unable to find require"}
    end
  end

  # Context starts from 1 while LSP starts from 0
  # which works for us since we want to insert the require on the next line 
  defp get_edit_range(context) do
    %Range{
      start: %Position{line: context[:line], character: 0},
      end: %Position{line: context[:line], character: 0}
    }
  end

  @indent ~r/^(\s*).*/
  defp get_indent(text, {_, defm_context, _}) do
    line = defm_context[:line] - 1

    indent =
      text
      |> Enum.at(line)
      |> then(&Regex.run(@indent, &1))
      |> List.last()

    indent <> @one_indentation_level
  end

  @top_level_macros [:import, :alias, :require]
  defp find_nearest_node_for_require({:defmodule, context, _} = ast) do
    top_level_macros =
      ast
      |> Macro.prewalker()
      |> Enum.filter(fn
        {:@, _, [{:moduledoc, _, _}]} -> true
        {macro, _, _} when macro in @top_level_macros -> true
        _ -> false
      end)

    case top_level_macros do
      [] ->
        context

      _ ->
        {_, context, _} = Enum.max_by(top_level_macros, fn {_, ctx, _} -> ctx[:line] end)
        context
    end
  end
end
