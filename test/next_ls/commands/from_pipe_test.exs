defmodule NextLS.Commands.FromPipeTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.Commands.FromPipe

  @moduletag :tmp_dir
  @parse_error_code -32_700

  describe "from-pipe" do
    test "works on one liners" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              map |> Enum.to_list()
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 2, "character" => 5}
      expected_line = Enum.at(text, 2)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               FromPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Enum.to_list(map)"
      assert range.start.line == 2
      assert range.start.character == 0
      assert range.end.line == 2
      assert range.end.character == String.length(expected_line)
    end

    test "works on one liners with multiple pipes" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              map |> Enum.to_list() |> Map.new()
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 2, "character" => 5}
      expected_line = Enum.at(text, 2)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               FromPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Enum.to_list(map) |> Map.new()"
      assert range.start.line == 2
      assert range.start.character == 0
      assert range.end.line == 2
      assert range.end.character == String.length(expected_line)
    end

    test "works on separate lines when the cursor is on the pipe" do
      # When the cursor is on the pipe
      # We should get the line before it to build the ast
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              map
              |> Enum.to_list()
              |> Map.new()
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 3, "character" => 5}
      expected_line = Enum.at(text, 3)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               FromPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Enum.to_list(map)"
      assert range.start.line == 2
      assert range.start.character == 0
      assert range.end.line == 3
      assert range.end.character == String.length(expected_line)
    end

    test "works on separate lines when the cursor is on the var" do
      # When the cursor is on the var
      # we should get the next line to build the ast
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              map
              |> Enum.to_list()
              |> Map.new()
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 2, "character" => 5}
      expected_line = Enum.at(text, 3)
      indent = "    "

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               FromPipe.new(%{uri: uri, text: text, position: position})

      assert edit.new_text == indent <> "Enum.to_list(map)"
      assert range.start.line == 2
      assert range.start.character == 0
      assert range.end.line == 3
      assert range.end.character == String.length(expected_line)
    end

    test "we get an error reply if the ast is bad" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              |> map
              |> Enum.to_list()
            end
          end
          """,
          "\n"
        )

      position = %{"line" => 3, "character" => 5}

      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} =
               FromPipe.new(%{uri: uri, text: text, position: position})

      assert message =~ "syntax error before"
    end

    test "we handle schematic errors" do
      assert %GenLSP.ErrorResponse{code: @parse_error_code, message: message} =
               FromPipe.new(%{bad_arg: :is_very_bad})

      assert message =~ "position: \"expected a map\""
    end
  end
end
