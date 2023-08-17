defmodule NextLS.WorkspacesTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]
  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())

    [cwd: tmp_dir]
  end

  setup %{cwd: cwd} do
    File.mkdir_p!(Path.join(cwd, "proj_one/lib"))
    File.write!(Path.join(cwd, "proj_one/mix.exs"), mix_exs())
    peace = Path.join(cwd, "proj_one/lib/peace.ex")

    File.write!(peace, """
    defmodule MyApp.Peace do
      def and_love() do
        "✌️"
      end
    end
    """)

    File.mkdir_p!(Path.join(cwd, "proj_two/lib"))
    File.write!(Path.join(cwd, "proj_two/mix.exs"), mix_exs())
    bar = Path.join(cwd, "proj_two/lib/bar.ex")

    File.write!(bar, """
    defmodule Bar do
      def run() do
        MyApp.Peace.and_love()
      end
    end
    """)

    [bar: bar, peace: peace]
  end

  setup :with_lsp

  @tag root_paths: ["proj_one"]
  test "starts a new runtime when you add a workspace folder", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_request(client, "client/registerCapability", fn _params -> nil end)
    assert_is_ready(context, "proj_one")
    assert_compiled(context, "proj_one")

    notify(client, %{
      method: "workspace/didChangeWorkspaceFolders",
      jsonrpc: "2.0",
      params: %{
        event: %{
          added: [
            %{name: "#{context.module}-proj_two", uri: "file://#{Path.join(cwd, "proj_two")}"}
          ],
          removed: []
        }
      }
    })

    assert_is_ready(context, "proj_two")
    assert_compiled(context, "proj_two")
  end

  @tag root_paths: ["proj_one", "proj_two"]
  test "stops the runtime when you remove a workspace folder", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_request(client, "client/registerCapability", fn _params -> nil end)
    assert_is_ready(context, "proj_one")
    assert_is_ready(context, "proj_two")

    assert_compiled(context, "proj_one")
    assert_compiled(context, "proj_two")

    notify(client, %{
      method: "workspace/didChangeWorkspaceFolders",
      jsonrpc: "2.0",
      params: %{
        event: %{
          added: [],
          removed: [
            %{name: "#{context.module}-proj_two", uri: "file://#{Path.join(cwd, "proj_two")}"}
          ]
        }
      }
    })

    message = "[NextLS] The runtime for #{context.module}-proj_two has successfully shut down."

    assert_notification "window/logMessage", %{
      "message" => ^message
    }
  end

  @tag root_paths: ["proj_one"]
  test "can register for workspace/didChangedWatchedFiles", %{client: client} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_request(client, "client/registerCapability", fn params ->
      assert params == %{
               "registrations" => [
                 %{
                   "id" => "file-watching",
                   "method" => "workspace/didChangeWatchedFiles",
                   "registerOptions" => %{
                     "watchers" => [
                       %{"kind" => 7, "globPattern" => "**/*.ex"},
                       %{"kind" => 7, "globPattern" => "**/*.exs"},
                       %{"kind" => 7, "globPattern" => "**/*.leex"},
                       %{"kind" => 7, "globPattern" => "**/*.eex"},
                       %{"kind" => 7, "globPattern" => "**/*.heex"},
                       %{"kind" => 7, "globPattern" => "**/*.sface"}
                     ]
                   }
                 }
               ]
             }

      nil
    end)

    assert_is_ready(context, "proj_one")
    assert_compiled(context, "proj_one")
  end

  @tag root_paths: ["proj_one"]
  test "can receive workspace/didChangeWatchedFiles notification", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_request(client, "client/registerCapability", fn _params -> nil end)

    assert_is_ready(context, "proj_one")
    assert_compiled(context, "proj_one")

    notify(client, %{
      method: "workspace/didChangeWatchedFiles",
      jsonrpc: "2.0",
      params: %{changes: [%{type: 3, uri: "file://#{Path.join(cwd, "proj_one/lib/peace.ex")}"}]}
    })
  end
end
