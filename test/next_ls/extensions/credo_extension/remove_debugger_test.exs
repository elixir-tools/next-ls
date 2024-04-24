defmodule NextLS.CredoExtension.CodeAction.RemoveDebuggerTest do
  use ExUnit.Case, async: true

  import NextLS.Test

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.CredoExtension.CodeAction.RemoveDebugger

  @uri "file:///home/owner/my_project/hello.ex"

  test "removes debugger checks" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            IO.inspect(arg)
            foo(arg)
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
          foo(arg)
        end
      end
      """)

    start = %Position{character: 4, line: 2}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Remove `&IO.inspect/1` 3:8"

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "works for all credo checks" do
    checks = [
      {"Elixir.Credo.Check.Warning.Dbg", "dbg()", "dbg/0", ""},
      {"Elixir.Credo.Check.Warning.Dbg", "dbg(arg)", "dbg/1", "arg"},
      {"Elixir.Credo.Check.Warning.Dbg", "Kernel.dbg()", "Kernel.dbg/0", ""},
      {"Elixir.Credo.Check.Warning.IExPry", "IEx.pry()", "IEx.pry/0", ""},
      {"Elixir.Credo.Check.Warning.IoInspect", "IO.inspect(foo, label: ~s/bar/)", "IO.inspect/2", "foo"},
      {"Elixir.Credo.Check.Warning.IoPuts", "IO.puts(arg)", "IO.puts/1", ""},
      {"Elixir.Credo.Check.Warning.MixEnv", "Mix.env()", "Mix.env/0", ""}
    ]

    for {check, code, title, edit} <- checks do
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

      expected =
        String.trim("""
        defmodule Test.Debug do
          def hello(arg) do
            #{edit}
            arg
          end
        end
        """)

      start = %Position{character: 4, line: 2}
      diagnostic = get_diagnostic(start, check: check, code: code)
      title = "Remove `&#{title}` #{start.line + 1}"

      assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)
      assert code_action.title =~ title

      assert %WorkspaceEdit{
               changes: %{
                 @uri => [%TextEdit{} = edit]
               }
             } = code_action.edit

      assert_is_text_edit(text, edit, expected)
    end
  end

  test "works on multiple expressions on one line" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            IO.inspect(arg, label: "Debugging"); world(arg)
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg; world(arg)
        end
      end
      """)

    start = %Position{character: 4, line: 2}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "handles pipe calls in the middle" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            arg
            |> Enum.map(&(&1 * &1))
            |> IO.inspect(label: "FOO")
            |> Enum.sum()
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
          |> Enum.map(&(&1 * &1))
          |> Enum.sum()
        end
      end
      """)

    start = %Position{character: 10, line: 4}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "handles pipe calls at the end" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            arg
            |> Enum.map(&(&1 * &1))
            |> Enum.sum()
            |> IO.inspect()
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
          |> Enum.map(&(&1 * &1))
          |> Enum.sum()
        end
      end
      """)

    start = %Position{character: 10, line: 5}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "handles pipe calls after an expr" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            arg |> IO.inspect()
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
        end
      end
      """)

    start = %Position{character: 10, line: 2}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "handles functions with only one expression" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          def hello(arg) do
            IO.inspect(arg, label: "DEBUG")
          end
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        def hello(arg) do
          arg
        end
      end
      """)

    start = %Position{character: 4, line: 2}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  test "handles inspects in module bodies" do
    text =
      String.split(
        """
        defmodule Test.Debug do
          @attr "foo"
          IO.inspect(@attr)
        end
        """,
        "\n"
      )

    expected =
      String.trim("""
      defmodule Test.Debug do
        @attr "foo"
        @attr
      end
      """)

    start = %Position{character: 4, line: 2}
    diagnostic = get_diagnostic(start)

    assert [code_action] = RemoveDebugger.new(diagnostic, text, @uri)

    assert %WorkspaceEdit{
             changes: %{
               @uri => [edit]
             }
           } = code_action.edit

    assert_is_text_edit(text, edit, expected)
  end

  defp get_diagnostic(start, opts \\ []) do
    check = Keyword.get(opts, :check, "Elixir.Credo.Check.Warning.IoInspect")
    code = Keyword.get(opts, :code, "IO.inspect/2")

    %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "credo", "check" => check},
      message: "There should be no calls to `#{code}`",
      source: "Elixir",
      range: %Range{
        start: start,
        end: %{start | character: 999}
      }
    }
  end
end
