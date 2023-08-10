defmodule NextLS.DefinitionTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir

  describe "function" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      remote = Path.join(cwd, "my_proj/lib/remote.ex")

      File.write!(remote, """
      defmodule Remote do
        def bang!() do
          "‼️"
        end
      end
      """)

      imported = Path.join(cwd, "my_proj/lib/imported.ex")

      File.write!(imported, """
      defmodule Imported do
        def boom() do
          "💣"
        end
      end
      """)

      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Foo do
        import Imported
        def run() do
          Remote.bang!()
          process()
        end

        defp process() do
          boom()
          :ok
        end
      end
      """)

      [bar: bar, imported: imported, remote: remote]
    end

    setup :with_lsp

    test "go to local function definition", %{client: client, bar: bar} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 4, character: 6},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 7,
            "character" => 0
          },
          "end" => %{
            "line" => 7,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end

    test "go to imported function definition", %{client: client, bar: bar, imported: imported} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 8, character: 5},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(imported)

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 1,
            "character" => 0
          },
          "end" => %{
            "line" => 1,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end

    test "go to remote function definition", %{client: client, bar: bar, remote: remote} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 3, character: 12},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(remote)

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 1,
            "character" => 0
          },
          "end" => %{
            "line" => 1,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end
  end

  describe "macro" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      remote = Path.join(cwd, "my_proj/lib/remote.ex")

      File.write!(remote, """
      defmodule Remote do
        defmacro bang!() do
          quote do
            "‼️"
          end
        end
      end
      """)

      imported = Path.join(cwd, "my_proj/lib/imported.ex")

      File.write!(imported, """
      defmodule Imported do
        defmacro boom() do
          quote do
            "💣"
          end
        end
      end
      """)

      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Foo do
        require Remote
        import Imported

        defmacrop process() do
          quote location: :keep do
            boom()
            :ok
          end
        end

        def run() do
          Remote.bang!()
          boom()
          process()
        end
      end
      """)

      [bar: bar, imported: imported, remote: remote]
    end

    setup :with_lsp

    test "go to local macro definition", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 14, character: 6},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 4,
            "character" => 0
          },
          "end" => %{
            "line" => 4,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end

    test "go to imported macro definition", %{client: client, bar: bar, imported: imported} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 13, character: 5},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(imported)

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 1,
            "character" => 0
          },
          "end" => %{
            "line" => 1,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end

    test "go to remote macro definition", %{client: client, bar: bar, remote: remote} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 12, character: 13},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(remote)

      assert_result 4, %{
        "range" => %{
          "start" => %{
            "line" => 1,
            "character" => 0
          },
          "end" => %{
            "line" => 1,
            "character" => 0
          }
        },
        "uri" => ^uri
      }
    end
  end

  describe "module" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      peace = Path.join(cwd, "my_proj/lib/peace.ex")

      File.write!(peace, """
      defmodule MyApp.Peace do
        def and_love() do
          "✌️"
        end
      end
      """)

      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Bar do
        alias MyApp.Peace
        def run() do
          Peace.and_love()
        end
      end
      """)

      [bar: bar, peace: peace]
    end

    setup :with_lsp

    test "go to module definition", %{client: client, bar: bar, peace: peace} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_is_ready(context, "my_proj")
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 3, character: 5},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(peace)

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{
                          "line" => 0,
                          "character" => 0
                        },
                        "end" => %{
                          "line" => 0,
                          "character" => 0
                        }
                      },
                      "uri" => ^uri
                    },
                    500
    end
  end
end
