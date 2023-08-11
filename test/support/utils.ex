defmodule NextLS.Support.Utils do
  @moduledoc false
  import ExUnit.Assertions
  import ExUnit.Callbacks
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

  def with_lsp(%{tmp_dir: tmp_dir} = context) do
    root_paths =
      for path <- context[:root_paths] || [""] do
        Path.absname(Path.join(tmp_dir, path))
      end

    tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: :one))
    r_tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: :two))
    rvisor = start_supervised!({DynamicSupervisor, [strategy: :one_for_one]})
    start_supervised!({Registry, [keys: :duplicate, name: context.module]})
    extensions = [NextLS.ElixirExtension]
    cache = start_supervised!(NextLS.DiagnosticCache)

    server =
      server(NextLS,
        task_supervisor: tvisor,
        runtime_task_supervisor: r_tvisor,
        dynamic_supervisor: rvisor,
        registry: context.module,
        extensions: extensions,
        cache: cache
      )

    Process.link(server.lsp)

    client = client(server)

    assert :ok ==
             request(client, %{
               method: "initialize",
               id: 1,
               jsonrpc: "2.0",
               params: %{
                 capabilities: %{
                   workspace: %{
                     workspaceFolders: true
                   }
                 },
                 workspaceFolders:
                   for(
                     path <- root_paths,
                     do: %{uri: "file://#{path}", name: "#{context.module}-#{Path.basename(path)}"}
                   )
               }
             })

    [server: server, client: client]
  end

  defmacro assert_is_ready(
             context,
             name,
             timeout \\ Application.get_env(:ex_unit, :assert_receive_timeout)
           ) do
    quote do
      message = "[NextLS] Runtime for folder #{unquote(context).module}-#{unquote(name)} is ready..."

      assert_notification "window/logMessage", %{"message" => ^message}, unquote(timeout)
    end
  end

  def uri(path) when is_binary(path) do
    URI.to_string(%URI{
      scheme: "file",
      host: "",
      path: path
    })
  end

  defmacro assert_result2(
             id,
             pattern,
             timeout \\ Application.get_env(:ex_unit, :assert_receive_timeout)
           ) do
    quote do
      assert_receive %{
                       "jsonrpc" => "2.0",
                       "id" => unquote(id),
                       "result" => result
                     },
                     unquote(timeout)

      assert result == unquote(pattern)
    end
  end
end
