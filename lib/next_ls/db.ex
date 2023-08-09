defmodule NextLS.DB do
  @moduledoc false
  use GenServer

  import __MODULE__.Query

  @type query :: String.t()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, Keyword.take(args, [:name]))
  end

  @spec query(pid(), query(), list()) :: list()
  def query(server, query, args \\ []), do: GenServer.call(server, {:query, query, args})

  @spec symbols(pid()) :: list(map())
  def symbols(server), do: GenServer.call(server, :symbols)

  @spec insert_symbol(pid(), map()) :: :ok
  def insert_symbol(server, payload), do: GenServer.cast(server, {:insert_symbol, payload})

  @spec insert_reference(pid(), map()) :: :ok
  def insert_reference(server, payload), do: GenServer.cast(server, {:insert_reference, payload})

  def init(args) do
    file = Keyword.fetch!(args, :file)
    registry = Keyword.fetch!(args, :registry)
    logger = Keyword.fetch!(args, :logger)
    Registry.register(registry, :databases, %{})
    {:ok, conn} = Exqlite.Basic.open(file)

    NextLS.DB.Schema.init({conn, logger})

    {:ok,
     %{
       conn: conn,
       file: file,
       logger: logger
     }}
  end

  def handle_call({:query, query, args}, _from, %{conn: conn} = s) do
    rows = __query__({conn, s.logger}, query, args)

    {:reply, rows, s}
  end

  def handle_call(:symbols, _from, %{conn: conn} = s) do
    rows =
      __query__(
        {conn, s.logger},
        ~Q"""
        SELECT
            *
        FROM
            symbols;
        """,
        []
      )

    symbols =
      for [_pk, module, file, type, name, line, column] <- rows do
        %{
          module: module,
          file: file,
          type: type,
          name: name,
          line: line,
          column: column
        }
      end

    {:reply, symbols, s}
  end

  def handle_cast({:insert_symbol, symbol}, %{conn: conn} = s) do
    %{
      module: mod,
      module_line: module_line,
      struct: struct,
      file: file,
      defs: defs
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
      INSERT INTO symbols (module, file, type, name, line, 'column')
          VALUES (?, ?, ?, ?, ?, ?);
      """,
      [mod, file, "defmodule", mod, module_line, 1]
    )

    if struct do
      {_, _, meta, _} = defs[:__struct__]

      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, line, 'column')
            VALUES (?, ?, ?, ?, ?, ?);
        """,
        [mod, file, "defstruct", "%#{Macro.to_string(mod)}{}", meta[:line], 1]
      )
    end

    for {name, {:v1, type, _meta, clauses}} <- defs, {meta, _, _, _} <- clauses do
      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, line, 'column')
            VALUES (?, ?, ?, ?, ?, ?);
        """,
        [mod, file, type, name, meta[:line], meta[:column] || 1]
      )
    end

    {:noreply, s}
  end

  def handle_cast({:insert_reference, reference}, %{conn: conn} = s) do
    %{
      meta: meta,
      identifier: identifier,
      file: file,
      type: type,
      module: module
    } = reference

    col = meta[:column] || 0

    {{start_line, start_column}, {end_line, end_column}} =
      {{meta[:line], col},
       {meta[:line], col + String.length(identifier |> to_string() |> String.replace("Elixir.", ""))}}

    __query__(
      {conn, s.logger},
      ~Q"""
      INSERT INTO 'references' (identifier, arity, file, type, module, start_line, start_column, end_line, end_column)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      """,
      [identifier, reference[:arity], file, type, module, start_line, start_column, end_line, end_column]
    )

    {:noreply, s}
  end

  def __query__({conn, logger}, query, args) do
    args = Enum.map(args, &cast/1)

    case Exqlite.Basic.exec(conn, query, args) do
      {:error, %{message: message, statement: statement}, _} ->
        NextLS.Logger.error(logger, """
        sqlite3 error: #{message}

        statement: #{statement}
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
