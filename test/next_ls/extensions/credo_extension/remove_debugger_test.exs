defmodule NextLS.CredoExtension.CodeAction.RemoveDebuggerTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.CredoExtension.CodeAction.RemoveDebugger

  test "removes debugger checks" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello() do
            IO.inspect("foo")
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 0, line: 2}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.Dbg"},
      message: "you must require Logger before invoking the macro Logger.info/1",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = RemoveDebugger.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Remove debugger"

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "",
                   range: %Range{start: ^start, end: %{line: 3, character: 0}}
                 }
               ]
             }
           } = code_action.edit
  end

  test "works for all credo checks" do
    checks = %{
      "Elixir.Credo.Check.Warning.Dbg" => "dbg()",
      "Elixir.Credo.Check.Warning.IExPry" => "IEx.pry()",
      "Elixir.Credo.Check.Warning.IoInspect" => "IO.inspect(foo)",
      "Elixir.Credo.Check.Warning.IoPuts" => "IO.puts(arg)",
      "Elixir.Credo.Check.Warning.MixEnv" => "Mix.env()"
    }

    for {check, code} <- checks do
      text =
        String.split(
          """
          defmodule Test.Debug do
            def hello() do
              #{code}
            end
          end
          """,
          "\n"
        )

      start = %Position{character: 4, line: 2}

      diagnostic = %GenLSP.Structures.Diagnostic{
        data: %{"namespace" => "credo", "check" => check},
        message: "There should be no calls to `#{code}`",
        source: "Elixir",
        range: %GenLSP.Structures.Range{
          start: start,
          end: %{start | character: 999}
        }
      }

      uri = "file:///home/owner/my_project/hello.ex"

      assert [code_action] = RemoveDebugger.new(diagnostic, text, uri)
      assert is_struct(code_action, CodeAction)
      assert [diagnostic] == code_action.diagnostics
      assert code_action.title == "Remove debugger"

      assert %WorkspaceEdit{
               changes: %{
                 ^uri => [
                   %TextEdit{
                     new_text: "",
                     range: %Range{start: %{line: 2, character: 0}, end: %{line: 3, character: 0}}
                   }
                 ]
               }
             } = code_action.edit
    end
  end
end
