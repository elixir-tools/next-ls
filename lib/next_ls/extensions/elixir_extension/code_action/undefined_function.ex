defmodule NextLS.ElixirExtension.CodeAction.UndefinedFunction do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ASTHelpers

  def new(diagnostic, text, uri) do
    %Diagnostic{range: range, data: %{"info" => %{"name" => name, "arity" => arity}}} = diagnostic

    with {:ok, ast} <-
           text
           |> Enum.join("\n")
           |> Spitfire.parse(literal_encoder: &{:ok, {:__block__, &2, [&1]}}),
         {:ok, {:defmodule, meta, _} = defm} <- ASTHelpers.get_surrounding_module(ast, range.start) do
      indentation = get_indent(text, defm)

      position = %GenLSP.Structures.Position{
        line: meta[:end][:line] - 1,
        character: 0
      }

      params = if arity == "0", do: "", else: Enum.map_join(1..String.to_integer(arity), ", ", fn i -> "param#{i}" end)

      action = fn title, new_text ->
        %CodeAction{
          title: title,
          diagnostics: [diagnostic],
          edit: %WorkspaceEdit{
            changes: %{
              uri => [
                %TextEdit{
                  new_text: new_text,
                  range: %Range{
                    start: position,
                    end: position
                  }
                }
              ]
            }
          }
        }
      end

      [
        action.("Create public function #{name}/#{arity}", """

        #{indentation}def #{name}(#{params}) do

        #{indentation}end
        """),
        action.("Create private function #{name}/#{arity}", """

        #{indentation}defp #{name}(#{params}) do

        #{indentation}end
        """)
      ]
    end
  end

  @one_indentation_level "  "
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
end
