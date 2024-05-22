defmodule NextLS.EditHelpers do
  @moduledoc false

  @doc """
  This adds indentation to all lines except the first since the LSP expects a range for edits,
  where we get the range with the already original indentation for starters.

  It also skips empty lines since they don't need indentation.
  """
  @spec add_indent_to_edit(text :: String.t(), indent :: String.t()) :: String.t()
  @blank_lines ["", "\n"]
  def add_indent_to_edit(text, indent) do
    [first | rest] = String.split(text, "\n")

    if rest == [] do
      first
    else
      indented =
        Enum.map_join(rest, "\n", fn line ->
          if line in @blank_lines do
            line
          else
            indent <> line
          end
        end)

      first <> "\n" <> indented
    end
  end

  @doc """
  Gets the indentation level at the line number desired
  """
  @spec get_indent(text :: [String.t()], line :: non_neg_integer()) :: String.t()
  def get_indent(text, line) do
    text
    |> Enum.at(line)
    |> then(&Regex.run(~r/^(\s*).*/, &1))
    |> List.last()
  end
end
