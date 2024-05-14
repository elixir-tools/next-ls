defmodule NextLS.ElixirExtension.RequireTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ElixirExtension.CodeAction.Require

  test "adds require to module" do
    text =
      String.split(
        """
        defmodule Test.Require do
          def hello() do
            Logger.info("foo")
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 11, line: 2}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "elixir", "type" => "require"},
      message: "you must require Logger before invoking the macro Logger.info/1",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = Require.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Add missing require for Logger"

    edit_position = %GenLSP.Structures.Position{line: 1, character: 0}

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "  require Logger\n",
                   range: %Range{start: ^edit_position, end: ^edit_position}
                 }
               ]
             }
           } = code_action.edit
  end

  test "adds require after moduledoc" do
    text =
      String.split(
        """
        defmodule Test.Require do
          @moduledoc
          def hello() do
            Logger.info("foo")
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 0, line: 2}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "elixir", "type" => "require"},
      message: "you must require Logger before invoking the macro Logger.info/1",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = Require.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Add missing require for Logger"

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "  require Logger\n",
                   range: %Range{start: ^start, end: ^start}
                 }
               ]
             }
           } = code_action.edit
  end

  test "adds require after alias" do
    text =
      String.split(
        """
        defmodule Test.Require do
          @moduledoc
          import Test.Foo
          alias Test.Bar
          def hello() do
            Logger.info("foo")
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 0, line: 4}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "elixir", "type" => "require"},
      message: "you must require Logger before invoking the macro Logger.info/1",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = Require.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Add missing require for Logger"

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "  require Logger\n",
                   range: %Range{start: ^start, end: ^start}
                 }
               ]
             }
           } = code_action.edit
  end

  test "figures out the correct module" do
    text =
      String.split(
        """
        defmodule Test do
          defmodule Foo do
            def hello() do
              IO.inspect("foo")
            end
          end

          defmodule Require do
            @moduledoc
            import Test.Foo
            alias Test.Bar

            def hello() do
              Logger.info("foo")
            end
          end
        end
        """,
        "\n"
      )

    start = %Position{character: 0, line: 11}

    diagnostic = %GenLSP.Structures.Diagnostic{
      data: %{"namespace" => "elixir", "type" => "require"},
      message: "you must require Logger before invoking the macro Logger.info/1",
      source: "Elixir",
      range: %GenLSP.Structures.Range{
        start: start,
        end: %{start | character: 999}
      }
    }

    uri = "file:///home/owner/my_project/hello.ex"

    assert [code_action] = Require.new(diagnostic, text, uri)
    assert is_struct(code_action, CodeAction)
    assert [diagnostic] == code_action.diagnostics
    assert code_action.title == "Add missing require for Logger"

    assert %WorkspaceEdit{
             changes: %{
               ^uri => [
                 %TextEdit{
                   new_text: "    require Logger\n",
                   range: %Range{start: ^start, end: ^start}
                 }
               ]
             }
           } = code_action.edit
  end
end
