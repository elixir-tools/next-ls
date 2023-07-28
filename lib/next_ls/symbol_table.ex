defmodule NextLS.SymbolTable do
  @moduledoc false
  use GenServer

  defmodule Symbol do
    @moduledoc false
    defstruct [:file, :module, :type, :name, :line, :col]

    @type t :: %__MODULE__{
            file: String.t(),
            module: module(),
            type: atom(),
            name: atom(),
            line: integer(),
            col: integer()
          }
  end

  @type uri :: String.t()

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.take(args, [:path, :workspace, :registry]), Keyword.take(args, [:name]))
  end

  @spec put_symbols(pid() | atom(), list(tuple())) :: :ok
  def put_symbols(server, symbols), do: GenServer.cast(server, {:put_symbols, symbols})

  @spec put_reference(pid() | atom(), map()) :: :ok
  def put_reference(server, reference), do: GenServer.cast(server, {:put_reference, reference})

  @spec remove(pid() | atom(), uri()) :: :ok
  def remove(server, uri), do: GenServer.cast(server, {:remove, uri})

  @spec symbols(pid() | atom()) :: list(struct())
  def symbols(server), do: GenServer.call(server, :symbols)

  @spec symbols(pid() | atom(), String.t()) :: list(struct())
  def symbols(server, file), do: GenServer.call(server, {:symbols, file})

  @spec close(pid() | atom()) :: :ok | {:error, term()}
  def close(server), do: GenServer.call(server, :close)

  def init(args) do
    path = Keyword.fetch!(args, :path)
    name = Keyword.fetch!(args, :workspace)
    registry = Keyword.fetch!(args, :registry)

    {:ok, name} =
      :dets.open_file(:"symbol-table-#{name}",
        file: path |> Path.join("symbol_table.dets") |> String.to_charlist(),
        type: :duplicate_bag
      )

    {:ok, ref_name} =
      :dets.open_file(:"reference-table-#{name}",
        file: path |> Path.join("reference_table.dets") |> String.to_charlist(),
        type: :duplicate_bag
      )

    Registry.register(registry, :symbol_tables, %{symbol_table: name, reference_table: ref_name})

    {:ok, %{table: name, reference_table: ref_name}}
  end

  def handle_call({:symbols, file}, _, state) do
    symbols =
      case :dets.lookup(state.table, file) do
        [{_, symbols} | _rest] -> symbols
        _ -> []
      end

    {:reply, symbols, state}
  end

  def handle_call(:symbols, _, state) do
    symbols =
      :dets.foldl(
        fn {_key, symbol}, acc ->
          if String.match?(to_string(symbol.name), ~r/__.*__/) do
            acc
          else
            [symbol | acc]
          end
        end,
        [],
        state.table
      )

    {:reply, symbols, state}
  end

  def handle_call(:close, _, state) do
    :dets.close(state.table)
    :dets.close(state.reference_table)

    {:reply, :ok, state}
  end

  def handle_cast({:put_reference, reference}, state) do
    %{
      meta: meta,
      identifier: identifier,
      file: file
    } = reference

    col = meta[:column] || 0

    range =
      {{meta[:line], col},
       {meta[:line], col + String.length(identifier |> to_string() |> String.replace("Elixir.", ""))}}

    :dets.insert(state.reference_table, {
      {file, range},
      reference
    })

    {:noreply, state}
  end

  def handle_cast({:put_symbols, symbols}, state) do
    %{
      module: mod,
      module_line: module_line,
      struct: struct,
      file: file,
      defs: defs
    } = symbols

    :dets.delete(state.table, mod)

    :dets.insert(
      state.table,
      {mod,
       %Symbol{
         module: mod,
         file: file,
         type: :defmodule,
         name: Macro.to_string(mod),
         line: module_line,
         col: 1
       }}
    )

    if struct do
      {_, _, meta, _} = defs[:__struct__]

      :dets.insert(
        state.table,
        {mod,
         %Symbol{
           module: mod,
           file: file,
           type: :defstruct,
           name: "%#{Macro.to_string(mod)}{}",
           line: meta[:line],
           col: 1
         }}
      )
    end

    for {name, {:v1, type, _meta, clauses}} <- defs, {meta, _, _, _} <- clauses do
      :dets.insert(
        state.table,
        {mod,
         %Symbol{
           module: mod,
           file: file,
           type: type,
           name: name,
           line: meta[:line],
           col: meta[:column] || 1
         }}
      )
    end

    {:noreply, state}
  end

  def handle_cast({:remove, uri}, %{table: symbol_table, reference_table: reference_table} = state) do
    file = URI.parse(uri).path

    :dets.select_delete(symbol_table, [{{:_, %{file: :"$1"}}, [], [{:==, :"$1", file}]}])
    :dets.select_delete(reference_table, [{{{:"$1", :_}, :_}, [], [{:==, :"$1", file}]}])

    {:noreply, state}
  end
end
