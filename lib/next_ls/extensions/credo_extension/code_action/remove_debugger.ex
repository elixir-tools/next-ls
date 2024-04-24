defmodule NextLS.CredoExtension.CodeAction.RemoveDebugger do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  def new(diagnostic, text, uri) do
    %Diagnostic{} = diagnostic
    start = diagnostic.range.start

    with {:ok, ast} <- parse(text),
         {:ok, debugger_node} <- find_debugger(ast, start) do
      indent = EditHelpers.get_indent(text, diagnostic.range.start.line)
      ast_without_debugger = remove_debugger(debugger_node)
      range = make_range(debugger_node)

      formatted = Macro.to_string(ast_without_debugger)

      [
        %CodeAction{
          title: make_title(debugger_node),
          diagnostics: [diagnostic],
          edit: %WorkspaceEdit{
            changes: %{
              uri => [
                %TextEdit{
                  new_text: EditHelpers.add_indent_to_edit(formatted, indent),
                  range: range
                }
              ]
            }
          }
        }
      ]
    else
      _ ->
        []
    end
  end

  defp find_debugger(ast, position) do
    pos = [line: position.line + 1, column: position.character + 1]

    result =
      ast
      |> Z.zip()
      |> Z.traverse(nil, fn tree, acc ->
        node = Z.node(tree)
        range = Sourceror.get_range(node)

        if !acc &&
             (matches_debug?(node, pos) || matches_pipe?(node, pos)) &&
             Sourceror.compare_positions(range.start, pos) in [:lt, :eq] &&
             Sourceror.compare_positions(range.end, pos) in [:gt, :eq] do
          {tree, node}
        else
          {tree, acc}
        end
      end)

    case result do
      {_, nil} -> {:error, "could find a debugger to remove"}
      {_, node} -> {:ok, node}
    end
  end

  defp parse(lines) do
    lines
    |> Enum.join("\n")
    |> Spitfire.parse(literal_encoder: &{:ok, {:__block__, &2, [&1]}})
    |> case do
      {:error, ast, _errors} ->
        {:ok, ast}

      other ->
        other
    end
  end

  defp make_range(original_ast) do
    range = Sourceror.get_range(original_ast)

    %Range{
      start: %Position{line: range.start[:line] - 1, character: range.start[:column] - 1},
      end: %Position{line: range.end[:line] - 1, character: range.end[:column] - 1}
    }
  end

  defp matches_pipe?({:|>, ctx, [_, arg]}, pos), do: pos[:line] == ctx[:line] && matches_debug?(arg, pos)
  defp matches_pipe?(_, _), do: false

  defp matches_debug?({:dbg, ctx, _}, pos), do: pos[:line] == ctx[:line]

  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:IO]}, f]}, _, _}, pos) when f in [:puts, :inspect],
    do: pos[:line] == ctx[:line]

  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:IEx]}, :pry]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:Mix]}, :env]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:Kernel]}, :dbg]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?(_, _), do: false

  defp remove_debugger({:|>, _, [arg, _function]}), do: arg
  defp remove_debugger({{:., _, [{:__aliases__, _, [:IO]}, :inspect]}, _, [arg | _]}), do: arg
  defp remove_debugger({{:., _, [{:__aliases__, _, [:Kernel]}, :dbg]}, _, [arg | _]}), do: arg
  defp remove_debugger({:dbg, _, [arg | _]}), do: arg
  defp remove_debugger(_node), do: {:__block__, [], []}

  defp make_title({_, ctx, _} = node), do: "Remove `#{format_node(node)}` #{ctx[:line]}:#{ctx[:column]}"
  defp format_node({:|>, _, [_arg, function]}), do: format_node(function)

  defp format_node({{:., _, [{:__aliases__, _, [module]}, function]}, _, args}),
    do: "&#{module}.#{function}/#{Enum.count(args)}"

  defp format_node({:dbg, _, args}), do: "&dbg/#{Enum.count(args)}"
  defp format_node(node), do: Macro.to_string(node)
end
