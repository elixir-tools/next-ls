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

  @spec expand(pid(), Macro.t(), String.t()) :: any()
  def expand(server, ast, file) do
    GenServer.call(server, {:expand, ast, file}, :infinity)
  end

  @spec ready?(pid()) :: boolean()
  def ready?(server), do: GenServer.call(server, :ready?)

  @spec await(pid(), non_neg_integer()) :: :ok | :timeout
  def await(server, count \\ 50)

  def await(_server, 0) do
    :timeout
  end

  def await(server, count) do
    with {:alive, true} <- {:alive, Process.alive?(server)},
         true <- ready?(server) do
      :ok
    else
      {:alive, false} ->
        :timeout

      _ ->
        Process.sleep(500)
        await(server, count - 1)
    end
  end

  @spec compile(pid(), Keyword.t()) :: any()
  def compile(server, opts \\ []) do
    GenServer.call(server, {:compile, opts}, :infinity)
  end

  def boot(supervisor, opts) do
    DynamicSupervisor.start_child(supervisor, {NextLS.Runtime.Supervisor, opts})
  end

  def stop(supervisor, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
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
    lsp_pid = Keyword.fetch!(opts, :lsp_pid)
    uri = Keyword.fetch!(opts, :uri)
    parent = Keyword.fetch!(opts, :parent)
    logger = Keyword.fetch!(opts, :logger)
    task_supervisor = Keyword.fetch!(opts, :task_supervisor)
    registry = Keyword.fetch!(opts, :registry)
    on_initialized = Keyword.fetch!(opts, :on_initialized)
    db = Keyword.fetch!(opts, :db)
    mix_env = Keyword.fetch!(opts, :mix_env)
    mix_target = Keyword.fetch!(opts, :mix_target)
    elixir_exe = Keyword.get(opts, :elixir_exe, System.find_executable("elixir"))
    expand = Keyword.get(opts, :expand, false)

    Registry.register(registry, :runtimes, %{name: name, uri: uri, path: working_dir, db: db})
    Registry.put_meta(registry, {:expand, self()}, expand)

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
         elixir_exe when is_binary(elixir_exe) <- elixir_exe do
      exe =
        dir
        |> Path.join("cmd")
        |> Path.absname()

      env = [
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
      ]

      args =
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

      NextLS.Logger.info(logger, """
      Booting runtime for #{name}.

      - elixir: #{elixir_exe}
      - zombie wrapper script: #{exe}
      - working_dir: #{working_dir}
      - command: #{Enum.join(args, " ")}

      Environment: 

      #{Enum.map_join(env, "\n", fn {k, v} -> "#{k}=#{v}" end)}
      """)

      port =
        Port.open(
          {:spawn_executable, exe},
          [
            :use_stdio,
            :stderr_to_stdout,
            :binary,
            :stream,
            cd: working_dir,
            env: env,
            args: args
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
        with {:ok, host} = :inet.gethostname(),
             node = :"#{sname}@#{host}",
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

          version = :rpc.call(node, System, :version, [])

          expander = Version.match?(version, ">= 1.17.0-dev")
          NextLS.Logger.info(logger, "version=#{version} expander=#{expander}")

          {:ok, _} = :rpc.call(node, :_next_ls_private_compiler, :start, [])

          send(me, {:node, node, expander})
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
         lsp_pid: lsp_pid,
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

  # if this node is 1.17 or higher, we can just send the expansion request to it
  def handle_call({:expand, ast, file}, _from, %{node: node, expander: true} = state) do
    NextLS.Logger.info(state.logger, "expanding on the runtime node")
    reply = :rpc.call(node, :_next_ls_private_spitfire_env, :expand, [ast, file])
    {:reply, {:ok, reply}, state}
  end

  # else, we need to send it to the bonus runtime
  def handle_call({:expand, ast, file}, _from, %{expander: false, name: name} = state) do
    NextLS.Logger.info(state.logger, "expanding on the bonus node")

    [reply] =
      dispatch(state.registry, :bonus_runtimes, fn entries ->
        for {pid, %{name: ^name}} <- entries do
          NextLS.Runtime.Bonus.call(pid, {:_next_ls_private_spitfire_env, :expand, [ast, file]})
        end
      end)

    {:reply, reply, state}
  end

  def handle_call({:compile, opts}, _from, %{node: node, name: name} = state) do
    opts =
      opts
      |> Keyword.put_new(:working_dir, state.working_dir)
      |> Keyword.put_new(:registry, state.registry)
      |> Keyword.put(:from, self())

    with {:badrpc, error} <- :rpc.call(node, :_next_ls_private_compiler_worker, :enqueue_compiler, [opts]) do
      NextLS.Logger.error(state.logger, "Bad RPC call to node #{node}: #{inspect(error)}")
    end

    with false <- state.expander,
         [{:badrpc, error}] <-
           dispatch(state.registry, :bonus_runtimes, fn entries ->
             for {pid, %{name: ^name}} <- entries do
               :ok = NextLS.Runtime.Bonus.await(pid)
               NextLS.Runtime.Bonus.compile(pid, opts)
             end
           end) do
      NextLS.Logger.error(state.logger, "Bad RPC call to node #{node}: #{inspect(error)}")
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  # NOTE: these two callbacks are basically to forward the messages from the runtime to the
  #       LSP process so that progress messages can be dispatched
  def handle_info({:compiler_result, caller_ref, result}, state) do
    # we add the runtime name into the message
    send(state.lsp_pid, {:compiler_result, caller_ref, state.name, result})
    {:noreply, state}
  end

  def handle_info({:compiler_canceled, _caller_ref} = msg, state) do
    send(state.lsp_pid, msg)
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :port, port, _}, %{port: port} = state) do
    unless is_ready(state) do
      state.on_initialized.({:error, :portdown})
    end

    {:noreply, Map.delete(state, :node)}
  end

  def handle_info({:cancel, error}, state) do
    state.on_initialized.({:error, error})
    {:noreply, Map.delete(state, :node)}
  end

  def handle_info({:node, node, expander}, state) do
    Node.monitor(node, true)
    state.on_initialized.(:ready)
    {:noreply, state |> Map.put(:node, node) |> Map.put(:expander, expander)}
  end

  def handle_info({:nodedown, node}, %{node: node} = state) do
    {:stop, {:shutdown, :nodedown}, state}
  end

  # def handle_info(
  #       {port, {:data, "** (Mix) Can't continue due to errors on dependencies" <> _ = data}},
  #       %{port: port} = state
  #     ) do
  #   NextLS.Logger.log(state.logger, data)
  #   dbg(data)
  #
  #   state.on_initialized.({:error, :deps})
  #   {:noreply, state}
  # end

  def handle_info({port, {:data, "Unchecked dependencies" <> _ = data}}, %{port: port} = state) do
    NextLS.Logger.log(state.logger, data)

    Port.close(port)
    state.on_initialized.({:error, :deps})
    {:stop, {:shutdown, :unchecked_dependencies}, state}
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

  defp dispatch(registry, key, callback) do
    ref = make_ref()
    me = self()

    Registry.dispatch(registry, key, fn entries ->
      result = callback.(entries)

      send(me, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    end
  end
end
