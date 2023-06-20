defmodule NextLS.Runtime do
  @moduledoc false
  use GenServer

  @exe :code.priv_dir(:next_ls)
       |> Path.join("cmd")
       |> Path.absname()

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @type mod_fun_arg :: {atom(), atom(), list()}

  @spec call(pid(), mod_fun_arg()) :: any()
  def call(server, mfa), do: GenServer.call(server, {:call, mfa})

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

  def compile(server) do
    GenServer.call(server, :compile, :infinity)
  end

  @impl GenServer
  def init(opts) do
    sname = "nextls#{System.system_time()}"
    working_dir = Keyword.fetch!(opts, :working_dir)
    parent = Keyword.fetch!(opts, :parent)
    extension_registry = Keyword.fetch!(opts, :extension_registry)

    port =
      Port.open(
        {:spawn_executable, @exe},
        [
          :use_stdio,
          :stderr_to_stdout,
          :binary,
          :stream,
          cd: working_dir,
          env: [
            {'MIX_ENV', 'dev'},
            {'MIX_BUILD_ROOT', '.elixir-tools/_build'}
          ],
          args: [
            System.find_executable("elixir"),
            "--sname",
            sname,
            "-S",
            "mix",
            "run",
            "--no-halt",
            "--no-compile",
            "--no-start"
          ]
        ]
      )

    Port.monitor(port)

    me = self()

    Task.start_link(fn ->
      with {:ok, host} <- :inet.gethostname(),
           node <- :"#{sname}@#{host}",
           true <- connect(node, port, 120) do
        send(parent, {:log, "Connected to node #{node}"})

        :next_ls
        |> :code.priv_dir()
        |> Path.join("monkey/_next_ls_private_compiler.ex")
        |> then(&:rpc.call(node, Code, :compile_file, [&1]))

        send(me, {:node, node})
      else
        _ -> send(me, :cancel)
      end
    end)

    {:ok, %{port: port, parent: parent, errors: nil, extension_registry: extension_registry}}
  end

  @impl GenServer
  def handle_call(:ready?, _from, %{node: _node} = state) do
    {:reply, true, state}
  end

  def handle_call(:ready?, _from, state) do
    {:reply, false, state}
  end

  def handle_call({:call, {m, f, a}}, _from, %{node: node} = state) do
    reply = :rpc.call(node, m, f, a)
    {:reply, reply, state}
  end

  def handle_call(:compile, _, %{node: node} = state) do
    {_, errors} = :rpc.call(node, :_next_ls_private_compiler, :compile, [])

    Registry.dispatch(state.extension_registry, :extension, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:compiler, errors})
      end
    end)

    {:reply, errors, %{state | errors: errors}}
  end

  @impl GenServer
  def handle_info({:node, node}, state) do
    Node.monitor(node, true)
    {:noreply, Map.put(state, :node, node)}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    send(state.parent, {:log, data})
    {:noreply, state}
  end

  def handle_info({port, other}, %{port: port} = state) do
    send(state.parent, {:log, other})
    {:noreply, state}
  end

  defp connect(_node, _port, 0) do
    raise "failed to connect"
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
