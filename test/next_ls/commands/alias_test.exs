defmodule NextLS.Commands.AliasTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.Commands.Alias

  # @parse_error_code -32_700

  describe "alias-refactor" do
    test "works with single calls" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              Foo.Bar.to_list(map)
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
        defmodule MyApp do
          alias Foo.Bar

          def to_list(map) do
            Bar.to_list(map)
          end
        end
        """)

      line = 2
      position = %{"line" => line, "character" => 6}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Alias.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 0
      assert range.start.character == 0
      assert range.end.line == 4
      assert range.end.character == 3
    end

    test "works with multiple def calls" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              Foo.Bar.to_list(map)
            end

            def bar, do: :bar
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
        defmodule MyApp do
          alias Foo.Bar

          def to_list(map) do
            Bar.to_list(map)
          end

          def bar, do: :bar
        end
        """)

      line = 2
      position = %{"line" => line, "character" => 6}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Alias.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 0
      assert range.start.character == 0
      assert range.end.line == 6
      assert range.end.character == 3
    end

    test "works with aliasing multiple calls" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            def to_list(map) do
              Foo.Bar.to_list(map)
            end

            def bar do
              Foo.Bar.bar(:foo, :bar)
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
        defmodule MyApp do
          alias Foo.Bar

          def to_list(map) do
            Bar.to_list(map)
          end

          def bar do
            Bar.bar(:foo, :bar)
          end
        end
        """)

      line = 2
      position = %{"line" => line, "character" => 6}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Alias.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 0
      assert range.start.character == 0
      assert range.end.line == 8
      assert range.end.character == 3
    end

    test "works with nested modules" do
      uri = "my_app.ex"

      text =
        String.split(
          """
          defmodule MyApp do
            defmodule Foo.Baz do
              def to_list(map) do
                Foo.Bar.to_list(map)
              end

              def bar do
                Foo.Bar.bar(:foo, :bar)
              end
            end

            defmodule Quix do
              def quix do
                Foo.Bar.quix()
              end
            end
          end
          """,
          "\n"
        )

      expected_edit =
        String.trim("""
          defmodule Foo.Baz do
            alias Foo.Bar

            def to_list(map) do
              Bar.to_list(map)
            end

            def bar do
              Bar.bar(:foo, :bar)
            end
          end
        """)

      line = 3
      position = %{"line" => line, "character" => 8}

      assert %WorkspaceEdit{changes: %{^uri => [edit = %TextEdit{range: range}]}} =
               Alias.run(%{uri: uri, text: text, position: position})

      assert edit.new_text == expected_edit
      assert range.start.line == 1
      assert range.start.character == 2
      assert range.end.line == 9
      assert range.end.character == 7
    end
  end
end
