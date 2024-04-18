defmodule NextLS.EditHelpers do
  @moduledoc false
  # Having the format length to 121 would produce the least amount of churn in the case of the formatter
  @line_length 121

  @doc """
  This adds indentation to all lines except the first since the LSP expects a range for edits,
  where we get the range with the already original indentation for starters.

  It also skips empty lines since they don't need indentation.
  """
  @spec add_indent_to_edit(text :: String.t(), indent :: String.t()) :: String.t()
  @blank_lines ["", "\n"]
  def add_indent_to_edit(text, indent) do
    [first | rest] = String.split(text, "\n")

    if rest != [] do
      indented =
        Enum.map_join(rest, "\n", fn line ->
          if line not in @blank_lines do
            indent <> line
          else
            line
          end
        end)

      first <> "\n" <> indented
    else
      first
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

  @doc """
  Formats back the ast with the comments.
  """
  @spec to_string(ast :: Macro.t(), comments :: list(term)) :: String.t()
  def to_string(ast, comments) do
    to_algebra_opts = [comments: comments]

    ast
    |> Code.quoted_to_algebra(to_algebra_opts)
    |> Inspect.Algebra.format(@line_length)
    |> IO.iodata_to_binary()
  end
end
