defmodule NextLS.Commands.VariablesTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.Commands.Variables

  describe "extract" do
    test "works on simple variables" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              map = %{foo: :bar}
              Enum.to_list(map)
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
        defmodule MyApp do
          @map %{foo: :bar}
          def to_list(map) do
            Enum.to_list(@map)
          end
        end
        """)

      line = 2
      position = %{"line" => line, "character" => 6}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Variables.extract(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 0
      assert range.start.character == 0
      assert range.end.line == 5
      assert range.end.character == 3
    end

    test "does not replace variables in other scopes" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            defmodule Foo do
              def to_list(map) do
                map = %{foo: :bar}
                if 3 == 4 do
                  map
                else
                  fn map -> map end
                end

                Enum.to_list(map)
              end

              def to_string(map) do
                inspect(map)
              end
            end

            defmodule Foo do
              def to_list(map) do
                Enum.to_list(map)
              end
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
          defmodule Foo do
            @map %{foo: :bar}
            def to_list(map) do
              if 3 == 4 do
                @map
              else
                fn map -> map end
              end

              Enum.to_list(@map)
            end

            def to_string(map) do
              inspect(map)
            end
          end
        """)

      line = 3
      position = %{"line" => line, "character" => 8}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Variables.extract(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 1
      assert range.start.character == 2
      assert range.end.line == 16
      assert range.end.character == 5
    end
  end
end
