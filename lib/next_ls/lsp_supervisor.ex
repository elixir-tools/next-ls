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
      {m, f, a} =
        if @env == :prod, do: {Burrito.Util.Args, :get_arguments, []}, else: {System, :argv, []}

      argv = apply(m, f, a)

      {opts, _, _invalid} =
        OptionParser.parse(argv, strict: [version: :boolean, help: :boolean, stdio: :boolean, port: :integer])

      port =
        opts[:port] || # fallback to env port if not set by args
        case "NEXTLS_PORT" |> System.get_env("") |> Integer.parse() do
          {int_port, ""} -> int_port
          _bad_parse_or_error -> nil
        end

      help_text = """
      Next LS v#{NextLS.version()}

      The language server for Elixir that #{IO.ANSI.italic()}#{IO.ANSI.bright()}just#{IO.ANSI.reset()} works.

           Author: Mitchell Hanberg
        Home page: https://www.elixir-tools.dev/next-ls
      Source code: https://github.com/elixir-tools/next-ls

      nextls [flags]

      #{IO.ANSI.bright()}FLAGS#{IO.ANSI.reset()}

        --stdio             Use stdio as the transport mechanism
        --port <port>       Use TCP as the transport mechanism, with the given port
        --help              Show help
        --version           Show nextls version
      """

      cond do
        opts[:help] ->
          IO.puts(help_text)

          System.halt(0)

        opts[:version] ->
          IO.puts("#{NextLS.version()}")
          System.halt(0)

        true ->
          :noop
      end

      buffer_opts =
        cond do
          opts[:stdio] ->
            []

          is_integer(port) ->
            IO.puts("Starting on port #{port}")
            [communication: {GenLSP.Communication.TCP, [port: port]}]

          true ->
            IO.puts(help_text)

            System.halt(1)
        end

      auto_update =
        if "NEXTLS_AUTO_UPDATE" |> System.get_env("false") |> String.to_existing_atom() do
          [
            binpath:
              System.get_env(
                "NEXTLS_BINPATH",
                Path.expand("~/.cache/elixir-tools/nextls/bin/nextls")
              ),
            api_host: System.get_env("NEXTLS_GITHUB_API", "https://api.github.com"),
            github_host: System.get_env("NEXTLS_GITHUB", "https://github.com"),
            current_version: Version.parse!(NextLS.version())
          ]
        else
          false
        end

      children = [
        {DynamicSupervisor, name: NextLS.DynamicSupervisor},
        {Task.Supervisor, name: NextLS.TaskSupervisor},
        {Task.Supervisor, name: :runtime_task_supervisor},
        {GenLSP.Buffer, [name: NextLS.Buffer] ++ buffer_opts},
        {NextLS.DiagnosticCache, name: :diagnostic_cache},
        {Registry, name: NextLS.Registry, keys: :duplicate},
        {NextLS,
         auto_update: auto_update,
         buffer: NextLS.Buffer,
         cache: :diagnostic_cache,
         task_supervisor: NextLS.TaskSupervisor,
         runtime_task_supervisor: :runtime_task_supervisor,
         dynamic_supervisor: NextLS.DynamicSupervisor,
         registry: NextLS.Registry}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
