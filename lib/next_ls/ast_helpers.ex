defmodule NextLS.ASTHelpers do
  @moduledoc false

  @spec get_attribute_reference_name(String.t(), integer(), integer()) :: String.t() | nil
  def get_attribute_reference_name(file, line, column) do
    ast = ast_from_file(file)

    {_ast, name} =
      Macro.prewalk(ast, nil, fn
        {:@, [line: ^line, column: ^column], [{name, _meta, nil}]} = ast, _acc -> {ast, "@#{name}"}
        other, acc -> {other, acc}
      end)

    name
  end

  @spec get_module_attributes(String.t(), module()) :: [{atom(), String.t(), integer(), integer()}]
  def get_module_attributes(file, module) do
    reserved_attributes = Module.reserved_attributes()

    symbols = parse_symbols(file, module)

    Enum.filter(symbols, fn
      {:attribute, "@" <> name, _, _} ->
        not Map.has_key?(reserved_attributes, String.to_atom(name))

      _other ->
        false
    end)
  end

  defp parse_symbols(file, module) do
    ast = ast_from_file(file)

    {_ast, %{symbols: symbols}} =
      Macro.traverse(ast, %{modules: [], symbols: []}, &prewalk/2, &postwalk(&1, &2, module))

    symbols
  end

  # add module name to modules stack on enter
  defp prewalk({:defmodule, _, [{:__aliases__, _, module_name_atoms} | _]} = ast, acc) do
    modules = [module_name_atoms | acc.modules]
    {ast, %{acc | modules: modules}}
  end

  defp prewalk(ast, acc), do: {ast, acc}

  defp postwalk({:@, meta, [{name, _, args}]} = ast, acc, module) when is_list(args) do
    ast_module =
      acc.modules
      |> Enum.reverse()
      |> List.flatten()
      |> Module.concat()

    if module == ast_module do
      symbols = [{:attribute, "@#{name}", meta[:line], meta[:column]} | acc.symbols]
      {ast, %{acc | symbols: symbols}}
    else
      {ast, acc}
    end
  end

  # remove module name from modules stack on exit
  defp postwalk({:defmodule, _, [{:__aliases__, _, _modules} | _]} = ast, acc, _module) do
    [_exit_mudule | modules] = acc.modules
    {ast, %{acc | modules: modules}}
  end

  defp postwalk(ast, acc, _module), do: {ast, acc}

  defp ast_from_file(file) do
    file |> File.read!() |> Code.string_to_quoted!(columns: true)
  end
end
