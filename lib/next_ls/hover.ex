defmodule NextLS.Hover do
  alias GenLSP.Structures.{
    Hover,
    MarkupContent,
    Position,
    Range
  }

  alias NextLS.ReferenceTable
  alias NextLS.Runtime

  @spec fetch(lsp :: GenLSP.LSP.t(), uri :: String.t(), position :: Position.t()) :: Hover.t() | nil
  def fetch(lsp, uri, position) do
    position = {position.line + 1, position.character + 1}
    document = Enum.join(lsp.assigns.documents[uri], "\n")

    with {module, function, range} <- find_reference(lsp, document, uri, position),
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

  defp find_reference(lsp, document, uri, position) do
    surround_context = Code.Fragment.surround_context(document, position)

    if surround_context == :none do
      nil
    else
      case ReferenceTable.reference(lsp.assigns.reference_table, URI.parse(uri).path, position) do
        [%{type: :function, module: module, identifier: function} | _] ->
          {module, function, build_range(surround_context)}

        [%{type: :alias, module: module} | _] ->
          {module, nil, build_range(surround_context)}

        _other ->
          find_in_context(surround_context)
      end
    end
  end

  defp find_in_context(%{context: {:alias, module}} = context) do
    {to_module(module), nil, build_range(context)}
  end

  defp find_in_context(%{context: {:unquoted_atom, erlang_module}} = context) do
    {to_atom(erlang_module), nil, build_range(context)}
  end

  defp find_in_context(_context) do
    nil
  end

  defp fetch_docs(lsp, document, module, nil) do
    with {:ok, {_, _, _, _, docs, _, _} = docs_v1} <- request_docs(lsp, document, module) do
      print_doc(module, nil, nil, docs, docs_v1)
    end
  end

  defp fetch_docs(lsp, document, module, function) do
    with {:ok, {_, _, _, _, _, _, functions_docs} = docs_v1} <- request_docs(lsp, document, module),
         {_, _, [spec], function_docs, _} <- find_function_docs(functions_docs, function) do
      print_doc(module, function, spec, function_docs, docs_v1)
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

      {:ok, {:error, :chunk_not_found}} ->
        nil

      other ->
        other
    end
  end

  defp find_aliased_module(document, module) do
    module = to_quoted_module(module)

    ast =
      Code.string_to_quoted(document,
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

  defp send_fetch_docs_request(lsp, module) do
    Runtime.call(lsp.assigns.runtime, {Code, :fetch_docs, [module]})
  end

  defp build_range(%{begin: {line, start}, end: {_, finish}}) do
    %Range{
      start: %Position{line: line - 1, character: start - 1},
      end: %Position{line: line - 1, character: finish - 1}
    }
  end

  defp find_function_docs(docs, function) do
    Enum.find(docs, fn
      {{type, ^function, _}, _, _, _, _} when type in [:function, :macro] -> true
      _ -> false
    end)
  end

  defp print_doc(_module, _function, _spec, :none, _docs_v1) do
    nil
  end

  defp print_doc(_module, _function, _spec, :hidden, _docs_v1) do
    nil
  end

  defp print_doc(_module, nil, _spec, doc, {_, _, _, "text/markdown", _, _, _}) do
    doc["en"]
  end

  defp print_doc(_module, _function, spec, doc, {_, _, _, "text/markdown", _, _, _}) do
    print_function_spec(spec) <> doc["en"]
  end

  defp print_doc(module, nil, _spec, _doc, {_, _, :erlang, "application/erlang+html", _, _, _} = docs_v1) do
    :shell_docs.render(module, docs_v1, %{ansi: false}) |> Enum.join()
  end

  defp print_doc(module, function, spec, _doc, {_, _, :erlang, "application/erlang+html", _, _, _} = docs_v1) do
    print_function_spec(spec) <> (:shell_docs.render(module, function, docs_v1, %{ansi: false}) |> Enum.join())
  end

  defp print_function_spec(spec) do
    "### " <> spec <> "\n\n"
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
    |> String.replace("Elixir.", "")
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end
end
