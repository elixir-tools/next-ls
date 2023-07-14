defmodule NextLS.Support.Utils do
  use ExUnit.Case

  import GenLSP.Test
  def mix_exs do
    """
    defmodule Project.MixProject do
      use Mix.Project

      def project do
        [
          app: :project,
          version: "0.1.0",
          elixir: "~> 1.10",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      # Run "mix help compile.app" to learn about applications.
      def application do
        [
          extra_applications: [:logger]
        ]
      end

      # Run "mix help deps" to learn about dependencies.
      defp deps do
        []
      end
    end
    """
  end

  def setup_project_dir(%{tmp_dir: tmp_dir}) do
    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "mix.exs"), mix_exs())
    [cwd: tmp_dir]
  end

  def with_lsp(%{tmp_dir: tmp_dir, test: test}) do
    root_path = Path.absname(tmp_dir)
    server = start_lsp(tmp_dir, suffix: test)
    client = client(server)

    assert :ok ==
             request(client, %{
               method: "initialize",
               id: 1,
               jsonrpc: "2.0",
               params: %{capabilities: %{}, rootUri: "file://#{root_path}"}
             })

    [server: server, client: client, cwd: root_path]
  end

  def uri(path) when is_binary(path) do
    URI.to_string(%URI{
      scheme: "file",
      host: "",
      path: path
    })
  end

  def start_lsp(tmp_dir, opts \\ []) do
    prefix = Keyword.get(opts, :prefix)
    suffix = Keyword.get(opts, :suffix)

    wrapped_name = fn name ->
      String.to_atom("#{suffix}#{name}#{prefix}")
    end

    registry_name = wrapped_name.("registry")

    tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: wrapped_name.("tvisor")))
    r_tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: wrapped_name.("r_tvisor")))
    rvisor = start_supervised!(Supervisor.child_spec({DynamicSupervisor, strategy: :one_for_one, name: wrapped_name.("rvisor")}, id: wrapped_name.("rvisor")))
    cache = start_supervised!(Supervisor.child_spec(NextLS.DiagnosticCache, id: wrapped_name.("cache")))
    symbol_table = start_supervised!(Supervisor.child_spec({NextLS.SymbolTable, path: tmp_dir}, id: wrapped_name.("symbol_table")))
    start_supervised!({Registry, keys: :unique, name: registry_name})

    server =
      server(NextLS,
        task_supervisor: tvisor,
        runtime_task_supervisor: r_tvisor,
        dynamic_supervisor: rvisor,
        extension_registry: registry_name,
        extensions: [NextLS.ElixirExtension],
        cache: cache,
        symbol_table: symbol_table,
        name: wrapped_name.("server")
      )

    Process.link(server.lsp)

    server
  end
end
