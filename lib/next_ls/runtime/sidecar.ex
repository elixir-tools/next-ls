defmodule NextLS.Runtime.Sidecar do
  @moduledoc false
  use GenServer

  alias NextLS.DB

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.drop(args, [:name]), Keyword.take(args, [:name]))
  end

  def init(args) do
    db = Keyword.fetch!(args, :db)

    {:ok, %{db: db}}
  end

  def handle_info({:tracer, payload}, state) do
    "Elixir." <> module_name = to_string(payload.module)
    all_symbols = parse_symbols(payload.file, module_name)
    attributes = filter_attributes(all_symbols)

    payload = Map.put_new(payload, :symbols, attributes)
    DB.insert_symbol(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference, :attribute}, payload}, state) do
    ast = payload.file |> File.read!() |> Code.string_to_quoted!(columns: true)
    location = [line: payload.meta[:line], column: payload.meta[:column]]

    {_ast, name} =
      Macro.prewalk(ast, nil, fn
        {:@, ^location, [{name, _meta, nil}]} = ast, _acc -> {ast, name}
        other, acc -> {other, acc}
      end)

    if name do
      payload = %{payload | identifier: "@#{name}"}
      DB.insert_reference(state.db, payload)
    end

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference}, payload}, state) do
    DB.insert_reference(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :start}, filename}, state) do
    DB.clean_references(state.db, filename)

    {:noreply, state}
  end

  defp filter_attributes(symbols) do
    symbols
    |> Enum.filter(&match?({:attribute, _, _, _}, &1))
    |> Enum.reject(fn {_, "@" <> name, _, _} ->
      Map.has_key?(Module.reserved_attributes(), String.to_atom(name))
    end)
  end

  defp parse_symbols(file, module) do
    ast = file |> File.read!() |> Code.string_to_quoted!(columns: true)

    {_ast, %{symbols: symbols}} =
      Macro.traverse(ast, %{modules: [], symbols: []}, &prewalk/2, &postwalk(&1, &2, module))

    symbols
  end

  # add module name to modules stack on enter
  defp prewalk({:defmodule, _, [{:__aliases__, _, modules} | _]} = ast, acc) do
    modules_string =
      modules
      |> Enum.map(&Atom.to_string/1)
      |> Enum.intersperse(".")
      |> List.to_string()

    modules = [modules_string | acc.modules]

    {ast, %{acc | modules: modules}}
  end

  defp prewalk(ast, acc), do: {ast, acc}

  defp postwalk({:@, meta, [{name, _, args}]} = ast, acc, module) when is_list(args) do
    # get current module for this node
    ast_module =
      acc.modules
      |> Enum.reverse()
      |> Enum.intersperse(".")
      |> List.to_string()

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
end
