defmodule NextLS.Commands.ToPipe do
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

    case to_pipe_edit(text, position) do
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

  defp find_pipe_line(text, line) do
    coursor_text_line = Enum.at(text, line)

    range = %Range{
      start: %Position{line: line, character: 0},
      end: %Position{line: line, character: String.length(coursor_text_line)}
    }

    {:ok, coursor_text_line, range}
  end

  defp to_pipe_edit(text, %{line: line}) do
    with {:ok, lines, range_to_edit} <- find_pipe_line(text, line),
         {:ok, indent} <- get_indent(text, line),
         {:ok, first_argument, alias_qualified} <- get_first_argument(lines),
         {:ok, edit} <- get_edit(lines, first_argument, alias_qualified) do
      {:ok, %TextEdit{new_text: indent <> edit, range: range_to_edit}}
    else
      {:error, _message} = error ->
        error
    end
  end

  defp get_edit(lines, first_argument, alias_qualified) do
    lines
    |> Code.string_to_quoted()
    |> extract_to_pipe(first_argument, alias_qualified)
    |> ast_to_string()
  end

  defp extract_to_pipe({:ok, ast}, {modules, function}, true = _alias) do
    {result, _} =
      Macro.prewalk(ast, _changed = false, fn
        {{:., _context, _args} = call, context,
         [{{:., _, [{:__aliases__, _, ^modules}, ^function]}, _, _} = first | rest]},
        false ->
          new_ast = {:|>, [line: 1], [first, {call, context, rest}]}
          {new_ast, true}

        ast, acc ->
          {ast, acc}
      end)

    {:ok, result}
  end

  defp extract_to_pipe({:ok, ast}, first_argument, true = _alias) do
    {result, _} =
      Macro.prewalk(ast, _changed = false, fn
        {{:., _context, _args} = call, context, [{^first_argument, _, _} = first | rest]}, false ->
          new_ast = {:|>, [line: 1], [first, {call, context, rest}]}
          {new_ast, true}

        ast, acc ->
          {ast, acc}
      end)

    {:ok, result}
  end

  defp extract_to_pipe({:ok, ast}, {modules, name}, false = _alias) do
    {result, _} =
      Macro.prewalk(ast, _changed = false, fn
        {call, context, [{{:., _, [{:__aliases__, _, ^modules}, ^name]}, _, _} = first | rest]}, false ->
          new_ast = {:|>, [line: 1], [first, {call, context, rest}]}
          {new_ast, true}

        ast, acc ->
          {ast, acc}
      end)

    {:ok, result}
  end

  defp extract_to_pipe({:ok, ast}, first_argument, false = _alias) do
    {result, _} =
      Macro.prewalk(ast, _changed = false, fn
        {call, context, [{^first_argument, _, _} = first | rest]}, false ->
          new_ast = {:|>, [line: 1], [first, {call, context, rest}]}
          {new_ast, true}

        ast, acc ->
          {ast, acc}
      end)

    {:ok, result}
  end

  defp extract_to_pipe({:error, _} = error, _first_argument, _alias), do: error

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

  def get_first_argument(line) do
    regex = ~r/\(\s*(.*?)(?=\s*,|\s*\))/

    case Regex.run(regex, line) do
      [_, first] ->
        [function, _] = String.split(line, first, parts: 2)

        alias_qualified =
          function
          |> String.split(" ")
          |> Enum.at(-1)
          |> function_call?()

        first = String.trim_trailing(first, "(")

        first =
          if function_call?(first) do
            {function, rest} =
              first
              |> String.split(".")
              |> List.pop_at(-1)

            modules = Enum.map(rest, &String.to_atom(&1))
            {modules, String.to_atom(function)}
          else
            String.to_atom(first)
          end

        {:ok, first, alias_qualified}

      _ ->
        {:error, "could not find argument to extract"}
    end
  end

  # Check if it's Foo.Bar.bar()
  # Since it can be a struct as well %Foo.Bar{}
  defp function_call?(string) do
    parts = String.split(string, ".")
    last = Enum.at(parts, -1)

    last != String.capitalize(last) && Enum.count(parts) > 1
  end
end
