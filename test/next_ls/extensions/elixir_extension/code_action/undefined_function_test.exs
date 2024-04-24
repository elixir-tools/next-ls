defmodule NextLS.ElixirExtension.UndefinedFunctionTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ElixirExtension.CodeAction.UndefinedFunction

  test "in outer module creates new private function inside current module" do
    text =
      String.split(
        """
        defmodule Test.Foo do
          defmodule Bar do
            def run() do
              :ok
            end
          end
          
          def hello() do
            bar(1, 2)
          end

          defmodule Baz do
            def run() do
              :error
            end
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 4, line: 8}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{
        "namespace" => "elixir",
        "type" => "undefined-function",
        "info" => %{
          "name" => "bar",
          "arity" => "2",
          "module" => "Elixir.Test.Foo"
        }
      },
      message:
        "undefined function bar/2 (expected Test.Foo to define such a function or for it to be imported, but none are available)",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 6}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = UndefinedFunction.new(diagnostic, text, uri)
    assert %CodeAction{} = code_action
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Create local private function bar/2"

    edit_position = %Position{line: 16, character: 0}

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: """

                     defp bar(param1, param2) do

                     end
                   """,
                   range: %Range{start: ^edit_position, end: ^edit_position}
                 }
               ]
             }
           } = code_action.edit
  end

  test "in inner module creates new private function inside current module" do
    text =
      String.split(
        """
        defmodule Test.Foo do
          defmodule Bar do
            def run() do
              bar(1, 2)
            end
          end

          defmodule Baz do
            def run() do
              :error
            end
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 6, line: 3}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{
        "namespace" => "elixir",
        "type" => "undefined-function",
        "info" => %{
          "name" => "bar",
          "arity" => "2",
          "module" => "Elixir.Test.Foo.Bar"
        }
      },
      message:
        "undefined function bar/2 (expected Test.Foo to define such a function or for it to be imported, but none are available)",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 9}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = UndefinedFunction.new(diagnostic, text, uri)
    assert %CodeAction{} = code_action
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Create local private function bar/2"

    edit_position = %Position{line: 5, character: 0}

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: """

                       defp bar(param1, param2) do

                       end
                   """,
                   range: %Range{start: ^edit_position, end: ^edit_position}
                 }
               ]
             }
           } = code_action.edit
  end
end
