defmodule NextLS.SemanticTokens do
  @moduledoc false

  # alias GenLSP.Enumerations.SemanticTokenModifiers
  alias GenLSP.Enumerations.SemanticTokenTypes
  alias GenLSP.Structures.SemanticTokens
  alias GenLSP.Structures.SemanticTokensLegend

  @token_types %{
    SemanticTokenTypes.parameter() => 0
  }
  def legend do
    %SemanticTokensLegend{
      token_types: Map.keys(@token_types),
      token_modifiers: []
    }
  end

  def new(document) do
    code = Enum.join(document, "\n")

    {:ok, ast} = parse(code)

    result =
      code
      |> String.to_charlist()
      |> :spitfire_tokenizer.tokenize(1, 1, [])

    case result do
      {:ok, _, _, _, tokens} ->
        data = build_response(tokens, ast)
        %SemanticTokens{data: data}

      {:error, message} ->
        %GenLSP.ErrorResponse{code: GenLSP.Enumerations.ErrorCodes.parse_error(), message: inspect(message)}
    end
  end

  defp parse(code) do
    code
    |> Spitfire.parse(literal_encoder: &{:ok, {:__block__, &2, [&1]}})
    |> case do
      {:error, ast, _errors} ->
        {:ok, ast}

      other ->
        other
    end
  end

  defp build_response(tokens, ast) do
    do_build_response(tokens, ast, [])
  end

  defp do_build_response([], _ast, acc), do: acc |> Enum.sort_by(&{&1.line, &1.col}) |> build_deltas()
  # TODO: this should be made to work with macros such as `test "it works", %{foo: foo} do ...`
  defp do_build_response([{:identifier, _, definition}, {:paren_identifier, _, _}, {:"(", _} | rest], ast, acc)
       when definition in [:def, :defp, :defmacro, :defmacrop] do
    {parameters, rest} = take_parameters(rest, ast)
    do_build_response(rest, ast, parameters ++ acc)
  end

  defp do_build_response([_h | tail], ast, acc), do: do_build_response(tail, ast, acc)

  defp take_parameters(rest, ast) do
    {identifiers, rest} =
      Enum.split_while(rest, fn
        {:")", _} -> false
        _ -> true
      end)

    parameters =
      identifiers
      |> Enum.filter(&match?({:identifier, _, _}, &1))
      |> Enum.reduce([], fn {:identifier, {line, col, name}, _}, acc ->
        var_refs = NextLS.ASTHelpers.Variables.list_variable_references(ast, {line, col})

        parameters =
          Enum.map(var_refs, fn {_name, {line.._line_end//_, col..col_end//_}} ->
            {line, col, col_end - col + 1}
          end)

        [{line, col, length(name)} | parameters] ++ acc
      end)
      |> Enum.map(fn {line, col, length} ->
        make_token(line, col, length, SemanticTokenTypes.parameter())
      end)

    {parameters, rest}
  end

  defp make_token(line, col, length, type, modifiers \\ []) do
    %{line: line - 1, col: col - 1, length: length, type: type, modifiers: modifiers}
  end

  defp build_deltas([]), do: []

  defp build_deltas([first | _] = tokens) do
    modifiers = 0

    encoded_tokens =
      tokens
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.flat_map(fn [previous, current] ->
        delta_line = current.line - previous.line
        delta_char = if delta_line == 0, do: current.col - previous.col, else: current.col
        [delta_line, delta_char, current.length, @token_types[current.type], modifiers]
      end)

    [first.line, first.col, first.length, @token_types[first.type], modifiers] ++ encoded_tokens
  end
end
