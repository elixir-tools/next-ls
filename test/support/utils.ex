defmodule NextLS.Support.Utils do
  @moduledoc false
  import ExUnit.Assertions
  import ExUnit.Callbacks
  import GenLSP.Test

  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit

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

    bundle_base = Path.join(tmp_dir, ".bundled")
    mixhome = Path.join(tmp_dir, ".mix")
    mixarchives = Path.join(mixhome, "archives")
    File.mkdir_p!(bundle_base)

    r_tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: :two))
    rvisor = start_supervised!({DynamicSupervisor, [strategy: :one_for_one]}, id: :three)
    start_supervised!({Registry, [keys: :duplicate, name: context.module]}, id: :four)
    extensions = [elixir: NextLS.ElixirExtension, credo: NextLS.CredoExtension]
    cache = start_supervised!(NextLS.DiagnosticCache, id: :five)
    init_options = context[:init_options] || %{}

    pids = [
      :two,
      :three,
      :four,
      :five
    ]

    server =
      server(NextLS,
        runtime_task_supervisor: r_tvisor,
        dynamic_supervisor: rvisor,
        registry: context.module,
        extensions: extensions,
        cache: cache,
        bundle_base: bundle_base,
        mix_home: mixhome,
        mix_archives: mixarchives
      )

    Process.link(server.lsp)

    client = client(server)

    assert :ok ==
             request(client, %{
               method: "initialize",
               id: 1,
               jsonrpc: "2.0",
               params: %{
                 initializationOptions: init_options,
                 capabilities: %{
                   workspace: %{
                     workspaceFolders: true
                   },
                   window: %{
                     work_done_progress: false,
                     showMessage: %{}
                   }
                 },
                 workspaceFolders:
                   for(
                     path <- root_paths,
                     do: %{uri: "file://#{path}", name: "#{context.module}-#{Path.basename(path)}"}
                   )
               }
             })

    assert_result 1, _, 500

    [server: server, client: client, pids: pids]
  end

  defmacro assert_is_ready(
             context,
             name,
             timeout \\ Application.get_env(:ex_unit, :assert_receive_timeout)
           ) do
    quote do
      message = "[Next LS] Runtime for folder #{unquote(context).module}-#{unquote(name)} is ready..."

      assert_notification "window/logMessage", %{"message" => ^message}, unquote(timeout)
    end
  end

  defmacro assert_compiled(
             context,
             name,
             timeout \\ Application.get_env(:ex_unit, :assert_receive_timeout)
           ) do
    quote do
      message = "Compiled #{unquote(context).module}-#{unquote(name)}!"

      assert_notification "$/progress",
                          %{
                            "value" => %{
                              "kind" => "end",
                              "message" => ^message
                            }
                          },
                          unquote(timeout)
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

  defmacro did_open(client, file_path, text) do
    quote do
      assert :ok ==
               notify(unquote(client), %{
                 method: "textDocument/didOpen",
                 jsonrpc: "2.0",
                 params: %{
                   textDocument: %{
                     uri: uri(unquote(file_path)),
                     text: unquote(text),
                     languageId: "elixir",
                     version: 1
                   }
                 }
               })
    end
  end

  def apply_edit(code, edit) when is_binary(code), do: apply_edit(String.split(code, "\n"), edit)

  def apply_edit(lines, %TextEdit{} = edit) when is_list(lines) do
    text = edit.new_text
    %Range{start: %Position{line: startl, character: startc}, end: %Position{line: endl, character: endc}} = edit.range

    startl_text = Enum.at(lines, startl)
    prefix = String.slice(startl_text, 0, startc)

    endl_text = Enum.at(lines, endl)
    suffix = String.slice(endl_text, endc, String.length(endl_text) - endc)

    replacement = prefix <> text <> suffix

    new_lines = Enum.slice(lines, 0, startl) ++ [replacement] ++ Enum.slice(lines, endl + 1, Enum.count(lines))

    new_lines
    |> Enum.join("\n")
    |> String.trim()
  end

  defmacro assert_is_text_edit(code, edit, expected) do
    quote do
      actual = unquote(__MODULE__).apply_edit(unquote(code), unquote(edit))
      assert actual == unquote(expected)
    end
  end
end
