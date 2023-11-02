defmodule NextLS.Commands.ToPipeTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.Commands.ToPipe

  @moduletag :tmp_dir
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

      line = 2
      position = %{"line" => line, "character" => 5}
      expected_line = Enum.at(text, 2)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "map |> Enum.to_list()"
      assert range.start.line == line
      assert range.start.character == 0
      assert range.end.line == line
      assert range.end.character == String.length(expected_line)
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
      expected_line = Enum.at(text, line)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "map |> to_list()"
      assert range.start.line == line
      assert range.start.character == 0
      assert range.end.line == line
      assert range.end.character == String.length(expected_line)
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

      line = 2
      position = %{"line" => line, "character" => 5}
      expected_line = Enum.at(text, line)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Map.new() |> to_list()"
      assert range.start.line == line
      assert range.start.character == 0
      assert range.end.line == line
      assert range.end.character == String.length(expected_line)
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

      line = 2
      position = %{"line" => line, "character" => 5}
      expected_line = Enum.at(text, line)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               ToPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Map.new() |> Enum.to_list()"
      assert range.start.line == line
      assert range.start.character == 0
      assert range.end.line == line
      assert range.end.character == String.length(expected_line)
    end

    @test_scenarios [
      {"to_list(Map.new)", "Map.new() |> to_list()"},
      {"to_list(a, b, c)", "a |> to_list(b, c)"},
      {"Foo.Bar.baz(foo, bar)", "foo |> Foo.Bar.baz(bar)"},
      {"Foo.Bar.baz(foo, bar, Map.new())", "foo |> Foo.Bar.baz(bar, Map.new())"}
    ]

    test "small test scenarios work" do
      uri = "foo.ex"
      position = %{"line" => 0, "character" => 0}

      Enum.each(@test_scenarios, fn {to_transform, expected} ->
        assert %WorkspaceEdit{changes: %{^uri => [edit]}} =
                 ToPipe.new(%{uri: uri, text: [to_transform], position: position})

        assert edit.new_text == expected
      end)
    end

    test "we get an error reply if the ast is bad" do
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

      position = %{"line" => 2, "character" => 5}

      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} =
               ToPipe.new(%{uri: uri, text: text, position: position})

      assert message =~ "missing terminator"
    end

    test "we handle schematic errors" do
      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} =
               ToPipe.new(%{bad_arg: :is_very_bad})

      assert message =~ "position: \"expected a map\""
    end
  end
end
