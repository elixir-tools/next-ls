defmodule NextLS.SymbolTable do
  @moduledoc false
  use GenServer

  defmodule Symbol do
    defstruct [:file, :module, :type, :name, :line, :col]

    def new(args) do
      struct(__MODULE__, args)
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.take(args, [:path]), Keyword.take(args, [:name]))
  end

  @spec put_symbols(pid() | atom(), list(tuple())) :: :ok
  def put_symbols(server, symbols), do: GenServer.cast(server, {:put_symbols, symbols})

  @spec symbols(pid() | atom()) :: list(struct())
  def symbols(server), do: GenServer.call(server, :symbols)

  def close(server), do: GenServer.call(server, :close)

  def init(args) do
    path = Keyword.fetch!(args, :path)

    {:ok, name} =
      :dets.open_file(:symbol_table,
        file: Path.join(path, "symbol_table.dets") |> String.to_charlist(),
        type: :duplicate_bag
      )

    {:ok, %{table: name}}
  end

  def handle_call(:symbols, _, state) do
    symbols =
      :dets.foldl(
        fn {_key, symbol}, acc -> [symbol | acc] end,
        [],
        state.table
      )

    {:reply, symbols, state}
  end

  def handle_call(:close, _, state) do
    :dets.close(state.table)

    {:reply, :ok, state}
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

    for {name, {:v1, type, _meta, clauses}} <- defs, name != :__struct__, {meta, _, _, _} <- clauses do
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
end
