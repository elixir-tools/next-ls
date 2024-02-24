defmodule NextLS.ElixirExtension.UnusedVariableTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ElixirExtension.CodeAction.UnusedVariable

  test "adds an underscore to unused variables" do
    text =
      String.split(
        """
        defmodule Test.Unused do
          def hello() do
            foo = 3
            :world
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 4, line: 3}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "elixir", "type" => "unused_variable"},
      message: "variable \"foo\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = UnusedVariable.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics

    # We insert a single underscore character at the start position of the unused variable
    # Hence the start and end positions are matching the original start position in the diagnostic
    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "_",
                   range: %Range{start: ^start, end: ^start}
                 }
               ]
             }
           } = code_action.edit
  end
end
