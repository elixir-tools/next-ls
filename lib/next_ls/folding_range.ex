defmodule NextLS.FoldingRange do
  @moduledoc "Traverses the AST and creates folding ranges"

  alias GenLSP.Structures.FoldingRange
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias Sourceror.Zipper, as: Z

  @spec new(text :: String.t()) :: [FoldingRange.t()]
  def new(text) do
    with {:ok, ast} <- parse(text) do
      {_ast, foldings} =
        ast
        |> Z.zip()
        |> Z.traverse([], fn tree, acc ->
          node = Z.node(tree)
          if is_foldable?(node) do
            {tree, [node | acc]}
          else
            {tree, acc}
          end
        end)

      create_folding = fn node ->
        range = make_range(node)
        %FoldingRange{
          kind: "region",
          start_line: range.start.line,
          start_character: range.start.character,
          end_line: range.end.line,
          end_character: range.end.character,
          collapsed_text: Enum.at(text, range.start.character) <> " ..."
        }
      end

      Enum.map(foldings, create_folding)
    end
  end

  defp parse(lines) do
    lines
    |> Enum.join("\n")
    |> Spitfire.parse(literal_encoder: &{:ok, {:__block__, &2, [&1]}})
    |> case do
      {:error, ast, _errors} ->
        {:ok, ast}

      other ->
        other
    end
  end

  defp is_foldable?({_, _, [_name, [{{:__block__, _, [:do]}, _}]]}), do: true
  defp is_foldable?(_), do: false

  defp make_range({_, ctx, _}) do
    eoe = ctx[:end_of_expression]

    %Range{
      start: %Position{line: ctx[:line] - 1, character: ctx[:column] - 1},
      end: %Position{line: eoe[:line] - 1, character: eoe[:column] - 1}
    }
  end
end
