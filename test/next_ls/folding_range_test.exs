defmodule NextLS.AliasTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.FoldingRange, as: FR
  alias NextLS.FoldingRange

  test "creates a folding range for modules" do
    code = """
    defmodule MyModule do
      # Some text here
    end
    """

    assert [
             %FR{
               start_line: 0,
               start_character: 0,
               end_line: 2,
               end_character: 3,
               kind: "region",
               collapsed_text: "defmodule MyModule do ..."
             }
           ] = create_folding(code)
  end

  test "creates a folding range for functions" do
    code = """
    defmodule MyModule do
      def foo(a, b) do
        a + b
      end

      defp bar(a, b, c) do
        a + b + c
      end
    end
    """

    assert [
             %FR{
               start_line: 0,
               start_character: 0,
               end_line: 8,
               end_character: 3,
               kind: "region",
               collapsed_text: "defmodule MyModule do ..."
             },
             %FR{
               start_line: 1,
               start_character: 2,
               end_line: 3,
               end_character: 5,
               kind: "region",
               collapsed_text: "  def foo(a, b) do ..."
             },
             %FR{
               start_line: 5,
               start_character: 2,
               end_line: 7,
               end_character: 5,
               kind: "region",
               collapsed_text: "  defp bar(a, b, c) do ..."
             }
           ] = create_folding(code)
  end

  defp create_folding(code) do
    code
    |> String.split("\n")
    |> FoldingRange.new()
  end
end
