defmodule NextLSTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  import GenLSP.Test

  setup %{tmp_dir: tmp_dir} do
    File.cp_r!("test/support/project", tmp_dir)

    root_path = Path.absname(tmp_dir)

    tvisor = start_supervised!(Task.Supervisor)
    rvisor = start_supervised!({DynamicSupervisor, [strategy: :one_for_one]})
    start_supervised!({Registry, [keys: :unique, name: Registry.NextLSTest]})
    extensions = [NextLS.ElixirExtension]
    cache = start_supervised!(NextLS.DiagnosticCache)

    server =
      server(NextLS,
        task_supervisor: tvisor,
        dynamic_supervisor: rvisor,
        extension_registry: Registry.NextLSTest,
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

    assert_notification "window/logMessage",
                        %{"message" => "[NextLS] Runtime ready..."}

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

  test "publishes diagnostics once the client has initialized", %{client: client, cwd: cwd} do
    assert :ok ==
             notify(client, %{
               method: "initialized",
               jsonrpc: "2.0",
               params: %{}
             })

    assert_notification(
      "window/logMessage",
      %{
        "message" => "[NextLS] LSP Initialized!",
        "type" => 4
      }
    )

    # assert_notification("$/progress", %{"value" => %{"kind" => "begin"}})

    for file <- ["bar.ex"] do
      uri =
        to_string(%URI{
          host: "",
          scheme: "file",
          path: Path.join([cwd, "lib", file])
        })

      assert_notification(
        "textDocument/publishDiagnostics",
        %{
          "uri" => ^uri,
          "diagnostics" => [
            %{
              "source" => "Elixir",
              "severity" => 2,
              "message" =>
                "variable \"arg1\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
              "range" => %{
                "start" => %{"line" => 1, "character" => 0},
                "end" => %{"line" => 1, "character" => 999}
              }
            }
          ]
        }
      )
    end

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

  test "formats", %{client: client} do
    assert :ok ==
             notify(client, %{
               method: "initialized",
               jsonrpc: "2.0",
               params: %{}
             })

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: "file://lib/foo/bar.ex",
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo.Bar do
            def run() do


              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/formatting",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: "file://lib/foo/bar.ex"
        },
        options: %{
          insertSpaces: true,
          tabSize: 2
        }
      }
    }

    assert_result 2, nil

    assert_notification "window/logMessage",
                        %{"message" => "[NextLS] Runtime ready..."}

    request client, %{
      method: "textDocument/formatting",
      id: 3,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: "file://lib/foo/bar.ex"
        },
        options: %{
          insertSpaces: true,
          tabSize: 2
        }
      }
    }

    new_text = """
    defmodule Foo.Bar do
      def run() do
        :ok
      end
    end
    """

    assert_result(
      3,
      [
        %{
          "newText" => ^new_text,
          "range" => %{"start" => %{"character" => 0, "line" => 0}, "end" => %{"character" => 0, "line" => 8}}
        }
      ]
    )
  end
end
