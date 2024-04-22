defmodule NextLS.Test do
  @moduledoc """
  Macros to ease testing workspace edits
  """
  import ExUnit.Assertions

  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit

  def apply_edit(code, edit) when is_binary(code), do: apply_edit(String.split(code, "\n"), edit)

  def apply_edit(lines, %TextEdit{} = edit) when is_list(lines) do
    text = edit.new_text
    %Range{start: %Position{line: startl, character: startc}, end: %Position{line: endl, character: endc}} = edit.range

    startl_text = Enum.at(lines, startl)
    prefix = String.slice(startl_text, 0, startc)

    endl_text = Enum.at(lines, endl)
    suffix = String.slice(endl_text, endc, String.length(endl_text) - endc)

    replacement = prefix <> text <> suffix

    new_lines = Enum.slice(lines, 0, startl) ++ [replacement] ++ Enum.slice(lines, endl + 1, Enum.count(lines))
    new_lines
    |> Enum.join("\n")
    |> String.trim()
  end

  defmacro assert_is_text_edit(code, edit, expected) do
    quote do
      actual = apply_edit(unquote(code), unquote(edit))
      assert actual == unquote(expected)
    end
  end
end
