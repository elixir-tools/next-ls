defmodule NextLS.LSPSupervisor do
  @moduledoc false

  use Supervisor

  @env Mix.env()

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    if @env == :test do
      :ignore
    else
      {opts, _} =
        OptionParser.parse!(System.argv(),
          strict: [stdio: :boolean, port: :integer]
        )

      buffer_opts =
        cond do
          opts[:stdio] ->
            []

          is_integer(opts[:port]) ->
            IO.puts("Starting on port #{opts[:port]}")
            [communication: {GenLSP.Communication.TCP, [port: opts[:port]]}]

          true ->
            raise "Unknown option"
        end

      children = [
        {DynamicSupervisor, name: NextLS.RuntimeSupervisor},
        {Task.Supervisor, name: NextLS.TaskSupervisor},
        {GenLSP.Buffer, buffer_opts},
        {NextLS, task_supervisor: NextLS.TaskSupervisor, runtime_supervisor: NextLS.RuntimeSupervisor}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
