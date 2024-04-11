defmodule NextLS.Runtime.Bonus do
  @moduledoc """
  This bonus runtime is soley for the purpose of lifting newer Elixir features into the LSP.

  In cases where the user's local Elixir version is sufficiently new, this runtime will not
  be started.

  The code duplication in this module is okay, as the hope is to delete is as the required
  compiler and API changes in Elixir are upstreamed and most people are on the minimum
  version.
  """
  use GenServer

  alias OpenTelemetry.Tracer

  require NextLS.Runtime
  require OpenTelemetry.Tracer

  @env Mix.env()

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defguardp is_ready(state) when is_map_key(state, :node)

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
    with true <- ready?(server) do
      :ok
    else
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

  @impl true
  def init(opts) do
    sname = "nextls-runtime-bonus-#{System.system_time()}"
    name = Keyword.fetch!(opts, :name)
    working_dir = Keyword.fetch!(opts, :working_dir)
    lsp_pid = Keyword.fetch!(opts, :lsp_pid)
    uri = Keyword.fetch!(opts, :uri)
    logger = Keyword.fetch!(opts, :logger)
    task_supervisor = Keyword.fetch!(opts, :task_supervisor)
    registry = Keyword.fetch!(opts, :registry)
    # on_initialized = Keyword.fetch!(opts, :on_initialized)
    # db = Keyword.fetch!(opts, :db)
    # mix_env = Keyword.fetch!(opts, :mix_env)
    # mix_target = Keyword.fetch!(opts, :mix_target)
    elixir_exe = Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17/bin/elixir")

    [new_elixir] =
      dispatch(registry, :runtimes, fn entries ->
        for {pid, %{name: ^name}} <- entries do
          with true <- Process.alive?(pid),
               :ok <- NextLS.Runtime.await(pid) do
            version = NextLS.Runtime.execute!(pid, do: System.version())

            expander = Version.match?(version, " >= 1.17.0-dev")
            NextLS.Logger.info(logger, "in bonus, version=#{version} expander=#{expander}")
            expander
          end
        end
      end)

    if new_elixir in [true, :timeout] do
      NextLS.Logger.info(logger, "Ignoring bonus runtime, as local Elixir is sufficiently recent")
      :ignore
    else
      Registry.register(registry, :bonus_runtimes, %{name: name, uri: uri, path: working_dir})

      unless File.exists?(elixir_exe) do
        File.mkdir_p!(Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17"))
        base = Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17")

        :zip.unzip(~c"#{Path.join(:code.priv_dir(:next_ls), "precompiled-1-17.zip")}",
          cwd: ~c"#{base}"
        )

        for bin <- Path.wildcard(Path.join(base, "bin/*")) do
          File.chmod(bin, 0o755)
        end

        # NextLS.Logger.info(logger, "return value of unzip #{inspect(ret)}")
      end

      bindir = Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17/bin/")
      new_path = "#{bindir}:#{System.get_env("PATH")}"

      {_, 0} =
        System.cmd(Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17/bin/mix"), ["local.rebar", "--force"],
          cd: working_dir,
          env: [{"PATH", new_path}]
        )

      {_, 0} =
        System.cmd(Path.expand("~/.cache/elixir-tools/nextls/elixir/1.17/bin/mix"), ["local.hex", "--force"],
          cd: working_dir,
          env: [{"PATH", new_path}]
        )

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
          {~c"MIX_BUILD_ROOT", ~c".elixir-tools/_build2"},
          {~c"ROOTDIR", false},
          {~c"BINDIR", false},
          {~c"RELEASE_ROOT", false},
          {~c"RELEASE_SYS_CONFIG", false},
          {~c"PATH", String.to_charlist(new_path)},
          {~c"NEXTLS_TRACER", ~c"0"}
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
        Booting bonus runtime for #{name}.

        This runtime uses a bundled version of Elixir that has the latest version of the compiler.

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
                  NextLS.Logger.info(logger, "The bonus runtime for #{name} has successfully shut down.")

                reason ->
                  NextLS.Logger.error(
                    logger,
                    "The bonus runtime for #{name} has crashed with reason: #{inspect(reason)}"
                  )
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

            {:ok, _} = :rpc.call(node, :_next_ls_private_compiler, :start, [])

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
           lsp_pid: lsp_pid,
           errors: nil,
           registry: registry
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

  def handle_call({:compile, opts}, _from, %{node: node} = state) do
    opts =
      opts
      |> Keyword.put_new(:working_dir, state.working_dir)
      |> Keyword.put_new(:registry, state.registry)
      |> Keyword.put(:from, self())

    with {:badrpc, error} <- :rpc.call(node, :_next_ls_private_compiler_worker, :enqueue_compiler, [opts]) do
      NextLS.Logger.error(state.logger, "Bad RPC call to node #{node}: #{inspect(error)}")
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :port, port, _}, %{port: port} = state) do
    {:stop, {:shutdown, :portdown}, state}
  end

  def handle_info({:cancel, error}, state) do
    {:stop, error, state}
  end

  def handle_info({:node, node}, state) do
    Node.monitor(node, true)
    {:noreply, Map.put(state, :node, node)}
  end

  def handle_info({:nodedown, node}, %{node: node} = state) do
    {:stop, {:shutdown, :nodedown}, state}
  end

  def handle_info(
        {port, {:data, "** (Mix) Can't continue due to errors on dependencies" <> _ = data}},
        %{port: port} = state
      ) do
    NextLS.Logger.log(state.logger, data)

    {:noreply, state}
  end

  def handle_info({port, {:data, "Unchecked dependencies" <> _ = data}}, %{port: port} = state) do
    NextLS.Logger.log(state.logger, data)

    {:noreply, state}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    NextLS.Logger.info(state.logger, data)
    {:noreply, state}
  end

  def handle_info({port, other}, %{port: port} = state) do
    NextLS.Logger.info(state.logger, other)
    {:noreply, state}
  end

  def handle_info(_, state) do
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
