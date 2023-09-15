defmodule NextLS.DB do
  @moduledoc nil
  use GenServer

  import __MODULE__.Query

  @type query :: String.t()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, Keyword.take(args, [:name]))
  end

  @spec query(pid(), query(), list()) :: list()
  def query(server, query, args \\ []), do: GenServer.call(server, {:query, query, args}, :infinity)

  @spec insert_symbol(pid(), map()) :: :ok
  def insert_symbol(server, payload), do: GenServer.cast(server, {:insert_symbol, payload})

  @spec insert_reference(pid(), map()) :: :ok
  def insert_reference(server, payload), do: GenServer.cast(server, {:insert_reference, payload})

  @spec clean_references(pid(), String.t()) :: :ok
  def clean_references(server, filename), do: GenServer.cast(server, {:clean_references, filename})

  def init(args) do
    file = Keyword.fetch!(args, :file)
    registry = Keyword.fetch!(args, :registry)
    logger = Keyword.fetch!(args, :logger)
    activity = Keyword.fetch!(args, :activity)
    runtime = Keyword.fetch!(args, :runtime)

    {:ok, conn} = Exqlite.Basic.open(file)
    {:ok, mode} = NextLS.DB.Schema.init({conn, logger})

    Registry.register(registry, :databases, %{mode: mode, runtime: runtime})

    {:ok,
     %{
       conn: conn,
       file: file,
       logger: logger,
       activity: activity
     }}
  end

  def handle_call({:query, query, args}, _from, %{conn: conn} = s) do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    NextLS.DB.Activity.update(s.activity, count)
    rows = __query__({conn, s.logger}, query, args)

    {:reply, rows, s}
  end

  def handle_cast({:insert_symbol, symbol}, %{conn: conn} = s) do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    NextLS.DB.Activity.update(s.activity, count)

    %{
      module: mod,
      module_line: module_line,
      struct: struct,
      file: file,
      defs: defs,
      symbols: symbols,
      source: source
    } = symbol

    __query__(
      {conn, s.logger},
      ~Q"""
      DELETE FROM symbols
      WHERE module = ?;
      """,
      [mod]
    )

    __query__(
      {conn, s.logger},
      ~Q"""
      INSERT INTO symbols (module, file, type, name, line, 'column', source)
          VALUES (?, ?, ?, ?, ?, ?, ?);
      """,
      [mod, file, "defmodule", mod, module_line, 1, source]
    )

    if struct do
      {_, _, meta, _} = defs[:__struct__]

      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, line, 'column', source)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
        [mod, file, "defstruct", "%#{Macro.to_string(mod)}{}", meta[:line], 1, source]
      )
    end

    for {name, {:v1, type, _meta, clauses}} <- defs, {meta, _, _, _} <- clauses do
      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, line, 'column', source)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
        [mod, file, type, name, meta[:line], meta[:column] || 1, source]
      )
    end

    for {type, name, line, column} <- symbols do
      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, line, 'column', source)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
        [mod, file, type, name, line, column, source]
      )
    end

    {:noreply, s}
  end

  def handle_cast({:insert_reference, reference}, %{conn: conn} = s) do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    NextLS.DB.Activity.update(s.activity, count)

    %{
      meta: meta,
      identifier: identifier,
      file: file,
      type: type,
      module: module,
      source: source
    } = reference

    line = meta[:line] || 1
    col = meta[:column] || 0

    {start_line, start_column} = {line, col}
    {end_line, end_column} = {line, col + String.length(identifier |> to_string() |> String.replace("Elixir.", ""))}

    __query__(
      {conn, s.logger},
      ~Q"""
      INSERT INTO 'references' (identifier, arity, file, type, module, start_line, start_column, end_line, end_column, source)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """,
      [identifier, reference[:arity], file, type, module, start_line, start_column, end_line, end_column, source]
    )

    {:noreply, s}
  end

  def handle_cast({:clean_references, filename}, %{conn: conn} = s) do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    NextLS.DB.Activity.update(s.activity, count)

    __query__(
      {conn, s.logger},
      ~Q"""
      DELETE FROM 'references'
      WHERE file = ?;
      """,
      [filename]
    )

    {:noreply, s}
  end

  def __query__({conn, logger}, query, args) do
    args = Enum.map(args, &cast/1)

    case Exqlite.Basic.exec(conn, query, args) do
      {:error, %{message: message, statement: statement}, _} ->
        NextLS.Logger.warning(logger, """
        sqlite3 error: #{message}

        statement: #{statement}
        arguments: #{inspect(args)}
        """)

        {:error, message}

      result ->
        {:ok, rows, _} = Exqlite.Basic.rows(result)
        rows
    end
  end

  defp cast(arg) do
    cond do
      is_atom(arg) and String.starts_with?(to_string(arg), "Elixir.") ->
        Macro.to_string(arg)

      true ->
        arg
    end
  end
end
