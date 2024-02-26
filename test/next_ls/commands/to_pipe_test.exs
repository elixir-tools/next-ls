defmodule NextLS.Commands.ToPipeTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.Commands.ToPipe

  @parse_error_code -32_700

  describe "to-pipe" do
    test "works on one liners" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              Enum.to_list(map)
            end
          end
          """,
          "\n"
        )

      expected_edit = "map |> Enum.to_list()"

      line = 2
      position = %{"line" => line, "character" => 19}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == line
      assert range.start.character == 4
      assert range.end.line == line
      assert range.end.character == 21
    end

    test "works on one liners with imports" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            import Enum

            def to_list(map) do
              to_list(map)
            end
          end
          """,
          "\n"
        )

      line = 4
      position = %{"line" => line, "character" => 5}
      expected_edit = "map |> to_list()"

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == line
      assert range.start.character == 4
      assert range.end.line == line
      assert range.end.character == 16
    end

    test "works on one liners with nested function calls" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              to_list(Map.new())
            end
          end
          """,
          "\n"
        )

      expected_edit = "Map.new() |> to_list()"

      line = 2
      position = %{"line" => line, "character" => 10}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == line
      assert range.start.character == 4
      assert range.end.line == line
      assert range.end.character == 22
    end

    test "works on one liners with nested function calls with qualified calls" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              Enum.to_list(Map.new())
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim_trailing("""
        Map.new() |> Enum.to_list()
        """)

      line = 2
      position = %{"line" => line, "character" => 7}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == line
      assert range.start.character == 4
      assert range.end.line == 2
      assert range.end.character == 27
    end

    @test_scenarios [
      {6, "to_list(Map.new)", "Map.new() |> to_list()"},
      {6, "to_list(a, b, c)", "a |> to_list(b, c)"},
      {10, "Foo.Bar.baz(foo, bar)", "foo |> Foo.Bar.baz(bar)"},
      {10, "Foo.Bar.baz(foo, bar, Map.new())", "foo |> Foo.Bar.baz(bar, Map.new())"}
    ]

    test "small test scenarios work" do
      uri = "foo.ex"
      position = %{"line" => 0, "character" => 0}

      Enum.each(@test_scenarios, fn {character, to_transform, expected} ->
        dbg(to_transform)
        position = %{position | "character" => character}

        assert %WorkspaceEdit{changes: %{^uri => [edit]}} =
                 ToPipe.run(%{uri: uri, text: [to_transform], position: position})

        assert edit.new_text == expected
      end)
    end

    test "handles broken code" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def bad_ast(map) do
              Enum.to_list(foo
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 2, "character" => 15}

      assert %WorkspaceEdit{
               change_annotations: nil,
               changes: %{
                 "my_app.ex" => [
                   %TextEdit{
                     new_text: "foo |> Enum.to_list()",
                     range: %GenLSP.Structures.Range{
                       end: %GenLSP.Structures.Position{character: 20, line: 2},
                       start: %GenLSP.Structures.Position{character: 4, line: 2}
                     }
                   }
                 ]
               },
               document_changes: nil
             } =
               ToPipe.run(%{uri: uri, text: text, position: position})
    end

    test "handles bad cursor position" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          foo = [:one, two] 
          """,
          "\n"
        )

      position = %{"line" => 0, "character" => 5}

      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert message =~ "could not find an argument to extract at the cursor position"
    end

    test "handles schematic errors" do
      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} = ToPipe.run(%{bad_arg: :is_very_bad})

      assert message =~ "position: \"expected a map\""
    end

    test "handles an expression on multiple lines" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def all_odd?(map) do
              Enum.all?(map, fn {x, y} ->
                Integer.is_odd(y)
              end)
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim_trailing("""
        map
            |> Enum.all?(fn {x, y} ->
              Integer.is_odd(y)
            end)
        """)

      position = %{"line" => 2, "character" => 15}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 2
      assert range.start.character == 4
      assert range.end.line == 4
      assert range.end.character == 8
    end

    test "handles piping into a case/if/unless" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def check(result) do
              case result do
                {:ok, _success} -> :ok
                {:error, error} -> IO.inspect(error)
              end
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim_trailing("""
        result
            |> case do
              {:ok, _success} -> :ok
              {:error, error} -> IO.inspect(error)
            end
        """)

      position = %{"line" => 2, "character" => 13}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      dbg(edit.new_text)
      assert edit.new_text == expected_edit
      assert range.start.line == 2
      assert range.start.character == 4
      assert range.end.line == 5
      assert range.end.character == 7
    end

    test "handles nested calls in conditionals" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def check(result) do
              case parse_result(result) do
                {:ok, _success} -> :ok
                {:error, error} -> IO.inspect(error)
              end
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 2, "character" => 5}

      expected_edit =
        String.trim_trailing("""
        parse_result(result)
            |> case do
              {:ok, _success} -> :ok
              {:error, error} -> IO.inspect(error)
            end
        """)

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 2
      assert range.start.character == 4
      assert range.end.line == 5
      assert range.end.character == 7
    end

    test "another case" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          Enum.map(
            NextLS.ASTHelpers.Variables.list_variable_references(file, {line, col}),
            fn {_name, {startl..endl, startc..endc}} ->
              [file, startl, endl, startc, endc]
            end
          )
          """,
          "\n"
        )

      expected_edit =
        String.trim_trailing("""
        NextLS.ASTHelpers.Variables.list_variable_references(file, {line, col})
        |> Enum.map(fn {_name, {startl..endl, startc..endc}} ->
          [file, startl, endl, startc, endc]
        end)
        """)

      line = 0
      position = %{"line" => line, "character" => 5}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.run(%{uri: uri, text: text, position: position})

      dbg(range)

      assert edit.new_text == expected_edit
      assert range.start.line == line
      assert range.start.character == 0
      assert range.end.line == 5
      assert range.end.character == 1
    end
  end
end
