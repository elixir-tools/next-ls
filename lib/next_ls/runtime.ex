defmodule NextLS.Runtime do
  @moduledoc false
  use GenServer

  alias OpenTelemetry.Tracer

  require OpenTelemetry.Tracer

  @env Mix.env()
  defguardp is_ready(state) when is_map_key(state, :node)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @type mod_fun_arg :: {atom(), atom(), list()}

  @spec call(pid(), mod_fun_arg()) :: any()
  def call(server, mfa) do
    ctx = OpenTelemetry.Ctx.get_current()
    GenServer.call(server, {:call, mfa, ctx}, :infinity)
  end

  @spec ready?(pid()) :: boolean()
  def ready?(server), do: GenServer.call(server, :ready?)

  @spec await(pid(), non_neg_integer()) :: :ok | :timeout
  def await(server, count \\ 50)

  def await(_server, 0) do
    :timeout
  end

  def await(server, count) do
    if ready?(server) do
      :ok
    else
      Process.sleep(500)
      await(server, count - 1)
    end
  end

  @spec compile(pid(), Keyword.t()) :: any()
  def compile(server, opts \\ []) do
    GenServer.call(server, {:compile, opts}, :infinity)
  end

  defmacro execute!(runtime, block) do
    quote do
      {:ok, result} = NextLS.Runtime.execute(unquote_splicing([runtime, block]))
      result
    end
  end

  defmacro execute(runtime, do: block) do
    exprs =
      case block do
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end

    for expr <- exprs, reduce: quote(do: :ok) do
      ast ->
        mfa =
          case expr do
            {{:., _, [mod, func]}, _, args} ->
              [mod, func, args]

            {_func, _, _args} ->
              raise "#{Macro.to_string(__MODULE__)}.execute/2 cannot be called with local functions"
          end

        quote do
          unquote(ast)
          NextLS.Runtime.call(unquote(runtime), {unquote_splicing(mfa)})
        end
    end
  end

  @impl GenServer
  def init(opts) do
    sname = "nextls-runtime-#{System.system_time()}"
    name = Keyword.fetch!(opts, :name)
    working_dir = Keyword.fetch!(opts, :working_dir)
    uri = Keyword.fetch!(opts, :uri)
    parent = Keyword.fetch!(opts, :parent)
    logger = Keyword.fetch!(opts, :logger)
    task_supervisor = Keyword.fetch!(opts, :task_supervisor)
    registry = Keyword.fetch!(opts, :registry)
    on_initialized = Keyword.fetch!(opts, :on_initialized)
    db = Keyword.fetch!(opts, :db)
    mix_env = Keyword.fetch!(opts, :mix_env)
    mix_target = Keyword.fetch!(opts, :mix_target)

    Registry.register(registry, :runtimes, %{name: name, uri: uri, path: working_dir, db: db})

    pid =
      cond do
        is_pid(parent) -> parent
        is_atom(parent) -> Process.whereis(parent)
      end

    parent =
      pid
      |> :erlang.term_to_binary()
      |> Base.encode64()
      |> String.to_charlist()

    bindir = System.get_env("BINDIR")
    path = System.get_env("PATH")
    new_path = String.replace(path, bindir <> ":", "")

    with dir when is_list(dir) <- :code.priv_dir(:next_ls),
         elixir_exe when is_binary(elixir_exe) <- System.find_executable("elixir") do
      exe =
        dir
        |> Path.join("cmd")
        |> Path.absname()

      NextLS.Logger.info(logger, "Using `elixir` found at: #{elixir_exe}")

      port =
        Port.open(
          {:spawn_executable, exe},
          [
            :use_stdio,
            :stderr_to_stdout,
            :binary,
            :stream,
            cd: working_dir,
            env: [
              {~c"LSP", ~c"nextls"},
              {~c"NEXTLS_PARENT_PID", parent},
              {~c"MIX_ENV", ~c"#{mix_env}"},
              {~c"MIX_TARGET", ~c"#{mix_target}"},
              {~c"MIX_BUILD_ROOT", ~c".elixir-tools/_build"},
              {~c"ROOTDIR", false},
              {~c"BINDIR", false},
              {~c"RELEASE_ROOT", false},
              {~c"RELEASE_SYS_CONFIG", false},
              {~c"PATH", String.to_charlist(new_path)}
            ],
            args:
              [elixir_exe] ++
                if @env == :test do
                  ["--erl", "-kernel prevent_overlapping_partitions false"]
                else
                  []
                end ++
                [
                  "--no-halt",
                  "--sname",
                  sname,
                  "--cookie",
                  Node.get_cookie(),
                  "-S",
                  "mix",
                  "loadpaths",
                  "--no-compile"
                ]
          ]
        )

      Port.monitor(port)

      me = self()

      Task.Supervisor.async_nolink(task_supervisor, fn ->
        ref = Process.monitor(me)

        receive do
          {:DOWN, ^ref, :process, ^me, reason} ->
            case reason do
              :shutdown ->
                NextLS.Logger.info(logger, "The runtime for #{name} has successfully shut down.")

              reason ->
                NextLS.Logger.error(logger, "The runtime for #{name} has crashed with reason: #{inspect(reason)}")
            end
        end
      end)

      Task.start_link(fn ->
        with {:ok, host} <- :inet.gethostname(),
             node <- :"#{sname}@#{host}",
             true <- connect(node, port, 120) do
          NextLS.Logger.info(logger, "Connected to node #{node}")

          :next_ls
          |> :code.priv_dir()
          |> Path.join("monkey/_next_ls_private_compiler.ex")
          |> then(&:rpc.call(node, Code, :compile_file, [&1]))
          |> tap(fn
            {:badrpc, error} ->
              NextLS.Logger.error(logger, "Bad RPC call to node #{node}: #{inspect(error)}")
              send(me, {:cancel, error})

            _ ->
              :ok
          end)

          send(me, {:node, node})
        else
          error ->
            send(me, {:cancel, error})
        end
      end)

      {:ok,
       %{
         name: name,
         working_dir: working_dir,
         compiler_refs: %{},
         port: port,
         task_supervisor: task_supervisor,
         logger: logger,
         parent: parent,
         errors: nil,
         registry: registry,
         on_initialized: on_initialized
       }}
    else
      _ ->
        NextLS.Logger.error(
          logger,
          "Either failed to find the private cmd wrapper script or an `elixir`exe on your PATH"
        )

        {:stop, :failed_to_boot}
    end
  end

  @impl GenServer
  def handle_call(:ready?, _from, state) when is_ready(state) do
    {:reply, true, state}
  end

  def handle_call(:ready?, _from, state) do
    {:reply, false, state}
  end

  def handle_call(_, _from, state) when not is_ready(state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call({:call, {m, f, a}, ctx}, _from, %{node: node} = state) do
    token = OpenTelemetry.Ctx.attach(ctx)

    try do
      Tracer.with_span :"runtime.call", %{attributes: %{mfa: inspect({m, f, a})}} do
        reply = :rpc.call(node, m, f, a)
        {:reply, {:ok, reply}, state}
      end
    after
      OpenTelemetry.Ctx.detach(token)
    end
  end

  def handle_call({:compile, opts}, from, %{node: node} = state) do
    for {_ref, {task_pid, _from}} <- state.compiler_refs, do: Process.exit(task_pid, :kill)

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        if opts[:force] do
          File.rm_rf!(Path.join(state.working_dir, ".elixir-tools/_build"))
        end

        case :rpc.call(node, :_next_ls_private_compiler, :compile, []) do
          {:badrpc, error} ->
            NextLS.Logger.error(state.logger, "Bad RPC call to node #{node}: #{inspect(error)}")
            []

          {_, diagnostics} when is_list(diagnostics) ->
            Registry.dispatch(state.registry, :extensions, fn entries ->
              for {pid, _} <- entries, do: send(pid, {:compiler, diagnostics})
            end)

            NextLS.Logger.info(state.logger, "Compiled #{state.name}!")

            diagnostics

          unknown ->
            NextLS.Logger.warning(state.logger, "Unexpected compiler response: #{inspect(unknown)}")
            []
        end
      end)

    {:noreply, %{state | compiler_refs: Map.put(state.compiler_refs, task.ref, {task.pid, from})}}
  end

  @impl GenServer
  def handle_info({ref, errors}, %{compiler_refs: compiler_refs} = state) when is_map_key(compiler_refs, ref) do
    Process.demonitor(ref, [:flush])

    orig = elem(compiler_refs[ref], 1)
    GenServer.reply(orig, errors)

    {:noreply, %{state | compiler_refs: Map.delete(compiler_refs, ref)}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{compiler_refs: compiler_refs} = state)
      when is_map_key(compiler_refs, ref) do
    {:noreply, %{state | compiler_refs: Map.delete(compiler_refs, ref)}}
  end

  def handle_info({:DOWN, _, :port, port, _}, %{port: port} = state) do
    unless is_ready(state) do
      state.on_initialized.({:error, :portdown})
    end

    {:stop, {:shutdown, :portdown}, state}
  end

  def handle_info({:cancel, error}, state) do
    state.on_initialized.({:error, error})
    {:stop, error, state}
  end

  def handle_info({:node, node}, state) do
    Node.monitor(node, true)
    state.on_initialized.(:ready)
    {:noreply, Map.put(state, :node, node)}
  end

  def handle_info({:nodedown, node}, %{node: node} = state) do
    {:stop, {:shutdown, :nodedown}, state}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    NextLS.Logger.info(state.logger, data)
    {:noreply, state}
  end

  def handle_info({port, other}, %{port: port} = state) do
    NextLS.Logger.info(state.logger, other)
    {:noreply, state}
  end

  defp connect(_node, _port, 0) do
    false
  end

  defp connect(node, port, attempts) do
    if Node.connect(node) in [false, :ignored] do
      Process.sleep(1000)
      connect(node, port, attempts - 1)
    else
      true
    end
  end
end
