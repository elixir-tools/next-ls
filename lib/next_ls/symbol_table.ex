defmodule NextLS.SymbolTable do
  @moduledoc false
  use GenServer

  defmodule Symbol do
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

  @config_file_name "config.dets"
  @symbol_table_file_name "symbol_table.dets"
  @symbol_table_schema_version_key "symbol_table_schema_version"
  @symbol_table_schema_version_value "0.0.1"
  @reference_table_file_name "reference_table.dets"
  @reference_table_schema_version_key "reference_table_schema_version"
  @reference_table_schema_version_value "0.0.1"

  def start_link(opts) do
    init_opts = Keyword.take(opts, [:path, :config_table_name, :symbol_table_name, :reference_table_name])

    GenServer.start_link(__MODULE__, init_opts, Keyword.take(opts, [:name]))
  end

  @spec put_symbols(pid() | atom(), list(tuple())) :: :ok
  def put_symbols(server, symbols), do: GenServer.cast(server, {:put_symbols, symbols})

  @spec put_reference(pid() | atom(), map()) :: :ok
  def put_reference(server, reference), do: GenServer.cast(server, {:put_reference, reference})

  @spec symbols(pid() | atom()) :: list(struct())
  def symbols(server), do: GenServer.call(server, :symbols)

  @spec symbols(pid() | atom(), String.t()) :: list(struct())
  def symbols(server, file), do: GenServer.call(server, {:symbols, file})

  @spec close(pid() | atom()) :: :ok | {:error, term()}
  def close(server), do: GenServer.call(server, :close)

  @spec version_changed?(pid()) :: boolean()
  def version_changed?(server), do: GenServer.call(server, :version_changed?)

  @spec flush(pid()) :: :ok
  def flush(server), do: GenServer.cast(server, :flush)

  @spec tables(pid()) :: {atom(), atom()}
  def tables(server), do: GenServer.call(server, :tables)

  def init(args) do
    path = Keyword.fetch!(args, :path)
    config_table_name = Keyword.get(args, :config_table_name, :config_table)
    symbol_table_name = Keyword.get(args, :symbol_table_name, :symbol_table)
    reference_table_name = Keyword.get(args, :reference_table_name, :reference_table)

    File.mkdir_p!(path)

    {:ok, config} = open_file(config_table_name, Path.join(path, @config_file_name), type: :set)
    {:ok, name} = open_symbol_file(symbol_table_name, path)
    {:ok, ref_name} = open_reference_file(reference_table_name, path)

    {:ok, %{path: path, config: config, table: name, reference_table: ref_name}}
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
    :dets.close(state.config)
    :dets.close(state.table)
    :dets.close(state.reference_table)

    {:reply, :ok, state}
  end

  def handle_call(:version_changed?, _, state) do
    version_changed? = symbol_version_changed?(state.config) || reference_version_changed?(state.config)

    {:reply, version_changed?, state}
  end

  def handle_call(:tables, _, state) do
    {:reply, {state.table, state.reference_table, state.config}, state}
  end

  def handle_cast({:put_reference, reference}, state) do
    %{
      meta: meta,
      identifier: identifier,
      file: file
    } = reference

    col = meta[:column] || 0

    range =
      {{meta[:line], col}, {meta[:line], col + String.length(to_string(identifier) |> String.replace("Elixir.", ""))}}

    :dets.insert(state.reference_table, {file, {range, reference}})

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

  def handle_cast(:flush, state) do
    if symbol_version_changed?(state.config) do
      :dets.insert(state.config, {@symbol_table_schema_version_key, @symbol_table_schema_version_value})

      :ok = :dets.close(state.table)
      state.path |> Path.join(@symbol_table_file_name) |> File.rm()
      {:ok, _} = open_symbol_file(state.table, state.path)
    end

    if reference_version_changed?(state.config) do
      :dets.insert(state.config, {@reference_table_schema_version_key, @reference_table_schema_version_value})

      :ok = :dets.close(state.reference_table)
      state.path |> Path.join(@reference_table_file_name) |> File.rm()
      {:ok, _} = open_reference_file(state.reference_table, state.path)
    end

    {:noreply, state}
  end

  defp open_symbol_file(name, path) do
    open_file(name, Path.join(path, @symbol_table_file_name), type: :duplicate_bag)
  end

  defp open_reference_file(name, path) do
    open_file(name, Path.join(path, @reference_table_file_name), type: :duplicate_bag)
  end

  defp open_file(name, path, opts) do
    :dets.open_file(name, Keyword.merge(opts, file: String.to_charlist(path)))
  end

  defp symbol_version_changed?(config) do
    :dets.lookup(config, @symbol_table_schema_version_key) != [
      {@symbol_table_schema_version_key, @symbol_table_schema_version_value}
    ]
  end

  defp reference_version_changed?(config) do
    :dets.lookup(config, @reference_table_schema_version_key) != [
      {@reference_table_schema_version_key, @reference_table_schema_version_value}
    ]
  end
end
