defmodule NextLS.DB do
  @moduledoc nil
  use GenServer

  import __MODULE__.Query

  alias OpenTelemetry.Tracer

  require OpenTelemetry.Tracer

  @type query :: String.t()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, Keyword.take(args, [:name]))
  end

  @spec query(pid(), query(), list()) :: list()
  def query(server, query, opts \\ []) do
    ctx = OpenTelemetry.Ctx.get_current()
    GenServer.call(server, {:query, query, opts, ctx}, :infinity)
  end

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

  def handle_call({:query, query, args_or_opts, ctx}, _from, %{conn: conn} = s) do
    token = OpenTelemetry.Ctx.attach(ctx)

    try do
      Tracer.with_span :"db.query receive", %{attributes: %{query: query}} do
        {:message_queue_len, count} = Process.info(self(), :message_queue_len)
        NextLS.DB.Activity.update(s.activity, count)
        opts = if Keyword.keyword?(args_or_opts), do: args_or_opts, else: [args: args_or_opts]

        query =
          if opts[:select] do
            String.replace(query, ":select", Enum.map_join(opts[:select], ", ", &to_string/1))
          else
            query
          end

        rows =
          for row <- __query__({conn, s.logger}, query, opts[:args] || []) do
            if opts[:select] do
              opts[:select] |> Enum.zip(row) |> Map.new()
            else
              row
            end
          end

        {:reply, rows, s}
      end
    after
      OpenTelemetry.Ctx.detach(token)
    end
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

    for {name, {:v1, type, _meta, clauses}} <- defs, {meta, args, _, _} <- clauses do
      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO symbols (module, file, type, name, params, line, 'column', source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """,
        [
          mod,
          file,
          type,
          name,
          :erlang.term_to_binary(args),
          meta[:line],
          meta[:column] || 1,
          source
        ]
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

    if (meta[:line] && meta[:column]) || (reference[:range][:start] && reference[:range][:stop]) do
      line = meta[:line] || 1
      col = meta[:column] || 0

      {start_line, start_column} = reference[:range][:start] || {line, col}

      {end_line, end_column} =
        reference[:range][:stop] ||
          {line, col + String.length(identifier |> to_string() |> String.replace("Elixir.", "")) - 1}

      __query__(
        {conn, s.logger},
        ~Q"""
        INSERT INTO 'references' (identifier, arity, file, type, module, start_line, start_column, end_line, end_column, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        [identifier, reference[:arity], file, type, module, start_line, start_column, end_line, end_column, source]
      )
    end

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
    Tracer.with_span :"db.query process", %{attributes: %{query: query}} do
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
