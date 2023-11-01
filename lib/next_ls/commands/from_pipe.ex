defmodule NextLS.Commands.FromPipe do
  @moduledoc false
  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit

  defp opts do
    Schematic.map(%{
      position: Schematic.map(%{character: Schematic.int(), line: Schematic.int()}),
      uri: Schematic.str(),
      text: Schematic.list(Schematic.str())
    })
  end

  def new(opts) do
    {:ok, %{text: text, uri: uri, position: position}} = Schematic.unify(opts(), Map.new(opts))

    case from_pipe_edit(text, position) do
      {:ok, %TextEdit{} = edit} ->
        %WorkspaceEdit{
          changes: %{
            uri => [edit]
          }
        }

      {:error, message} ->
        %GenLSP.ErrorResponse{code: ErrorCodes.parse_error(), message: inspect(message)}
    end
  end

  defp find_pipe_lines(text, line) do
    coursor_text_line = Enum.at(text, line)

    if String.contains?(coursor_text_line, "|>") do
      case Code.string_to_quoted(coursor_text_line) do
        {:ok, _} ->
          range = %Range{
            start: %Position{line: line, character: 0},
            end: %Position{line: line, character: String.length(coursor_text_line)}
          }

          {:ok, [coursor_text_line], range}

        {:error, _} ->
          previous_line = Enum.at(text, line - 1)

          range = %Range{
            start: %Position{line: line - 1, character: 0},
            end: %Position{line: line, character: String.length(coursor_text_line)}
          }

          {:ok, [previous_line, coursor_text_line], range}
      end
    else
      next_line = Enum.at(text, line + 1)

      range = %Range{
        start: %Position{line: line, character: 0},
        end: %Position{line: line + 1, character: String.length(next_line)}
      }

      {:ok, [coursor_text_line, next_line], range}
    end
  end

  defp from_pipe_edit(text, %{line: line}) do
    with {:ok, lines, range_to_edit} <- find_pipe_lines(text, line),
         {:ok, indent} <- get_indent(text, line),
         {:ok, edit} <- get_edit(lines) do
      {:ok, %TextEdit{new_text: indent <> edit, range: range_to_edit}}
    else
      {:error, _message} = error ->
        error
    end
  end

  defp get_edit(lines) do
    lines
    |> Enum.join("\n")
    |> Code.string_to_quoted()
    |> inline_pipe()
    |> ast_to_string()
  end

  defp inline_pipe({:ok, ast}) do
    {result, _} =
      Macro.postwalk(ast, _changed = false, fn
        {:|>, _context, [left_arg, right_arg]}, false ->
          {call, context, args} = right_arg
          ast = {call, context, [left_arg | args]}
          {ast, true}

        ast, acc ->
          {ast, acc}
      end)

    {:ok, result}
  end

  defp inline_pipe({:error, _} = error), do: error

  defp ast_to_string({:ok, ast}), do: {:ok, Macro.to_string(ast)}
  defp ast_to_string({:error, _} = error), do: error

  defp get_indent(text, line) do
    indent =
      text
      |> Enum.at(line)
      |> then(&Regex.run(~r/^(\s*).*/, &1))
      |> List.last()

    {:ok, indent}
  end
end
