defmodule NextLS.Hover do
  alias GenLSP.Structures.{
    Hover,
    MarkupContent,
    Position,
    Range
  }

  alias NextLS.Runtime

  @spec fetch(lsp :: GenLSP.LSP.t(), document :: [String.t()], position :: Position.t()) :: Hover.t() | nil
  def fetch(lsp, document, position) do
    with {module, function, range} <- get_surround_context(document, position),
         docs when is_binary(docs) <- fetch_docs(lsp, document, module, function) do
      %Hover{
        contents: %MarkupContent{
          kind: "markdown",
          value: docs
        },
        range: range
      }
    end
  end

  defp get_surround_context(document, position) do
    hover_line = position.line + 1
    hover_column = position.character + 1

    case Code.Fragment.surround_context(Enum.join(document, "\n"), {hover_line, hover_column}) do
      %{context: {:dot, {:alias, module}, function}, begin: {line, context_begin}, end: {_, context_end}} ->
        {to_module(module), to_atom(function),
         %Range{
           start: %Position{line: line - 1, character: context_begin - 1},
           end: %Position{line: line - 1, character: context_end - 1}
         }}

      %{context: {:alias, module}, begin: {line, context_begin}, end: {_, context_end}} ->
        {to_module(module), nil,
         %Range{
           start: %Position{line: line - 1, character: context_begin - 1},
           end: %Position{line: line - 1, character: context_end - 1}
         }}

      _other ->
        nil
    end
  end

  defp fetch_docs(lsp, document, module, function) do
    if function do
      with {:ok, {_, _, _, _, _, _, functions_docs}} <- request_docs(lsp, document, module),
           {_, _, _, function_docs, _} <- find_function_docs(functions_docs, function) do
        get_en_doc(function_docs)
      end
    else
      with {:ok, {_, _, _, _, docs, _, _}} <- request_docs(lsp, document, module) do
        get_en_doc(docs)
      end
    end
  end

  defp request_docs(lsp, document, module, attempt \\ 1) do
    case send_fetch_docs_request(lsp, module) do
      {:error, :not_ready} ->
        nil

      {:ok, {:error, :module_not_found}} ->
        if attempt < 2 do
          aliased_module = find_aliased_module(document, module)

          if aliased_module do
            request_docs(lsp, document, from_quoted_module_to_module(aliased_module), attempt + 1)
          end
        end

      other ->
        other
    end
  end

  defp send_fetch_docs_request(lsp, module) do
    Runtime.call(lsp.assigns.runtime, {Code, :fetch_docs, [module]})
  end

  defp find_aliased_module(document, module) do
    module = to_quoted_module(module)

    ast =
      document
      |> Enum.join("\n")
      |> Code.string_to_quoted(
        unescape: false,
        token_metadata: true,
        columns: true
      )

    {_ast, aliased_module} =
      Macro.prewalk(ast, nil, fn
        # alias A, as: B
        {:alias, _, [{:__aliases__, _, aliased_module}, [as: {:__aliases__, _, ^module}]]} = expr, _ ->
          {expr, aliased_module}

        # alias A.{B, C}
        {:alias, _, [{{:., _, [{:__aliases__, _, namespace}, :{}]}, _, aliases}]} = expr, acc ->
          aliases = Enum.map(aliases, fn {:__aliases__, _, md} -> md end)

          if module in aliases do
            {expr, namespace ++ module}
          else
            {expr, acc}
          end

        # alias A.B.C
        {:alias, _, [{:__aliases__, _, aliased_module}]} = expr, acc ->
          offset = length(aliased_module) - length(module)

          if Enum.slice(aliased_module, offset..-1) == module do
            {expr, aliased_module}
          else
            {expr, acc}
          end

        expr, acc ->
          {expr, acc}
      end)

    aliased_module
  end

  defp from_quoted_module_to_module(quoted_module) do
    quoted_module
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(".")
    |> to_charlist()
    |> to_module()
  end

  defp to_module(charlist) when is_list(charlist) do
    String.to_atom("Elixir." <> to_string(charlist))
  end

  defp to_atom(charlist) when is_list(charlist) do
    charlist |> to_string() |> String.to_atom()
  end

  defp to_quoted_module(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.delete_at(0)
    |> Enum.map(&String.to_atom/1)
  end

  defp find_function_docs(docs, function) do
    Enum.find(docs, fn
      {{:function, ^function, _}, _, _, _, _} -> true
      _ -> false
    end)
  end

  defp get_en_doc(:none) do
    nil
  end

  defp get_en_doc(%{"en" => doc}) do
    doc
  end
end
