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

    assert [%FR{
      start_line: 0,
      start_character: 0,
      end_line: 2,
      end_character: 3,
      kind: "region",
      collapsed_text: "defmodule MyModule do ..."
    }] = create_folding(code)
  end

  defp create_folding(code) do
    code
    |> String.split("\n")
    |> FoldingRange.new()
  end
end
