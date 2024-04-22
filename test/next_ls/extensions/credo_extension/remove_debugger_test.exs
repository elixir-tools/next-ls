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
          def hello(arg) do
            IO.inspect(arg, label: "DEBUG")
            arg
          end
        end
        """,
        "\n"
      )

    expected_edit =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
        end
      end
      """)


    start = %Position{character: 4, line: 2}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.IoInspect"},
      message: "There should be no calls to `IO.inspect/2`",
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
                   new_text: expected_edit,
                   range: %Range{start: %{line: 0, character: 0}, end: %{line: 5, character: 3}}
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
            def hello(arg) do
              #{code}
              arg
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
        defmodule Test.Debug do
          def hello(arg) do
            arg
          end
        end
        """)

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
                     new_text: ^expected_edit,
                     range: %Range{start: %{line: 0, character: 0}, end: %{line: 5, character: 3}}
                   }
                 ]
               }
             } = code_action.edit
    end
  end

  test "works on multiple expressions on one line" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            IO.inspect(arg, label: "DEBUG"); arg
          end
        end
        """,
        "\n"
      )

    expected_edit =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
        end
      end
      """)


    start = %Position{character: 4, line: 2}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.IoInspect"},
      message: "There should be no calls to `IO.inspect/2`",
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
                   new_text: ^expected_edit,
                   range: %Range{start: %{line: 0, character: 0}, end: %{line: 5, character: 3}}
                 }
               ]
             }
           } = code_action.edit
  end

  test "handles pipe calls" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            arg
            |> Enum.map(& &1 * &1)
            |> IO.inspect(label: "FOO")
            |> Enum.sum()
          end
        end
        """,
        "\n"
      )

    expected_edit =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
          |> Enum.map(& &1 * &1)
          |> Enum.sum()
        end
      end
      """)


    start = %Position{character: 10, line: 4}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.IoInspect"},
      message: "There should be no calls to `IO.inspect/2`",
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
                   new_text: ^expected_edit,
                   range: %Range{start: %{line: 0, character: 0}, end: %{line: 5, character: 3}}
                 }
               ]
             }
           } = code_action.edit
  end
end
