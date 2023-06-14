defmodule NextLSTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  import GenLSP.Test

  setup %{tmp_dir: tmp_dir} do
    File.cp_r!("test/support/project", tmp_dir)

    root_path = Path.absname(tmp_dir)

    tvisor = start_supervised!(Task.Supervisor)
    rvisor = start_supervised!({DynamicSupervisor, [strategy: :one_for_one]})

    server =
      server(NextLS,
        task_supervisor: tvisor,
        runtime_supervisor: rvisor
      )

    Process.link(server.lsp)

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

  test "can start the LSP server", %{server: server} do
    assert alive?(server)
  end

  test "responds correctly to a shutdown request", %{client: client} do
    assert :ok ==
             notify(client, %{
               method: "initialized",
               jsonrpc: "2.0",
               params: %{}
             })

    assert_notification(
      "window/logMessage",
      %{"message" => "[NextLS] Runtime ready..."}
    )

    assert :ok ==
             request(client, %{
               method: "shutdown",
               id: 2,
               jsonrpc: "2.0",
               params: nil
             })

    assert_result(2, nil)
  end

  test "returns method not found for unimplemented requests", %{
    client: client
  } do
    id = System.unique_integer([:positive])

    assert :ok ==
             notify(client, %{
               method: "initialized",
               jsonrpc: "2.0",
               params: %{}
             })

    assert :ok ==
             request(client, %{
               method: "textDocument/documentSymbol",
               id: id,
               jsonrpc: "2.0",
               params: %{
                 textDocument: %{
                   uri: "file://file/doesnt/matter.ex"
                 }
               }
             })

    assert_notification(
      "window/logMessage",
      %{
        "message" => "[NextLS] Method Not Found: textDocument/documentSymbol",
        "type" => 2
      }
    )

    assert_error(
      ^id,
      %{
        "code" => -32_601,
        "message" => "Method Not Found: textDocument/documentSymbol"
      }
    )
  end

  test "can initialize the server" do
    assert_result(
      1,
      %{
        "capabilities" => %{
          "textDocumentSync" => %{
            "openClose" => true,
            "save" => %{
              "includeText" => true
            },
            "change" => 1
          }
        },
        "serverInfo" => %{"name" => "NextLS"}
      }
    )
  end

  @tag :pending
  test "publishes diagnostics once the client has initialized", %{
    client: _client,
    cwd: _cwd
  } do
    # assert :ok ==
    #          notify(client, %{
    #            method: "initialized",
    #            jsonrpc: "2.0",
    #            params: %{}
    #          })

    # assert_notification(
    #   "window/logMessage",
    #   %{
    #     "message" => "[NextLS] LSP Initialized!",
    #     "type" => 4
    #   }
    # )

    # assert_notification("$/progress", %{"value" => %{"kind" => "begin"}})

    # for file <- ["foo.ex", "bar.ex"] do
    #   uri =
    #     to_string(%URI{
    #       host: "",
    #       scheme: "file",
    #       path: Path.join([cwd, "lib", file])
    #     })

    #   assert_notification(
    #     "textDocument/publishDiagnostics",
    #     %{
    #       "uri" => ^uri,
    #       "diagnostics" => [
    #         %{
    #           "source" => "credo",
    #           "code" => "NextLS.Check.Readability.ModuleDoc",
    #           "codeDescription" => %{
    #             "href" => "https://hexdocs.pm/credo/NextLS.Check.Readability.ModuleDoc.html"
    #           },
    #           "severity" => 3
    #         }
    #       ]
    #     }
    #   )
    # end

    # uri =
    #   to_string(%URI{
    #     host: "",
    #     scheme: "file",
    #     path: Path.join([cwd, "lib", "code_action.ex"])
    #   })

    # assert_notification(
    #   "textDocument/publishDiagnostics",
    #   %{
    #     "uri" => ^uri,
    #     "diagnostics" => [
    #       %{"severity" => 3},
    #       %{"severity" => 3}
    #     ]
    #   }
    # )

    # assert_notification(
    #   "$/progress",
    #   %{
    #     "value" => %{
    #       "kind" => "end",
    #       "message" => "Found 5 issues"
    #     }
    #   }
    # )
  end
end
