defmodule NextLS.LSPSupervisor do
  @moduledoc false

  use Supervisor

  @env Mix.env()

  defmodule OptionsError do
    @moduledoc false
    defexception [:message]

    @impl true
    def exception(options) do
      msg = """
      Unknown Options: #{Enum.map_join(options, " ", fn {k, v} -> "#{k} #{v}" end)}

      Valid options:

      --stdio              Starts the server using stdio
      --port port-number   Starts the server using TCP on the given port
      """

      %OptionsError{message: msg}
    end
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    if @env == :test do
      :ignore
    else
      {opts, _, invalid} =
        OptionParser.parse(System.argv(),
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
            raise OptionsError, invalid
        end

      # FIXME: this directory should be inside the workspace, which will is not determined until
      # the LSP has begun initialization
      # The symbol table may need to started dynamically, like the extensions and the runtimes
      hidden_folder = Path.expand(".elixir-tools")
      File.mkdir_p!(hidden_folder)
      File.write!(Path.join(hidden_folder, ".gitignore"), "*\n")

      children = [
        {DynamicSupervisor, name: NextLS.DynamicSupervisor},
        {Task.Supervisor, name: NextLS.TaskSupervisor},
        {Task.Supervisor, name: :runtime_task_supervisor},
        {GenLSP.Buffer, buffer_opts},
        {NextLS.DiagnosticCache, name: :diagnostic_cache},
        {NextLS.SymbolTable, name: :symbol_table, path: hidden_folder},
        {Registry, name: NextLS.ExtensionRegistry, keys: :duplicate},
        {NextLS,
         cache: :diagnostic_cache,
         symbol_table: :symbol_table,
         task_supervisor: NextLS.TaskSupervisor,
         runtime_task_supervisor: :runtime_task_supervisor,
         dynamic_supervisor: NextLS.DynamicSupervisor,
         extension_registry: NextLS.ExtensionRegistry}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
