defmodule NextLSTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir

  describe "one" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        defstruct [:foo]

        def foo(arg1) do
        end
      end
      """)

      File.write!(Path.join(tmp_dir, "my_proj/lib/code_action.ex"), """
      defmodule Foo.CodeAction do
        # some comment

        defmodule NestedMod do
          def foo do
            :ok
          end
        end
      end
      """)

      File.write!(Path.join(tmp_dir, "my_proj/lib/foo.ex"), """
      defmodule Foo do
      end
      """)

      File.write!(Path.join(tmp_dir, "my_proj/lib/project.ex"), """
      defmodule Project do
        def hello do
          :world
        end
      end
      """)

      File.rm_rf!(Path.join(tmp_dir, ".elixir-tools"))

      :ok
    end

    setup :with_lsp

    test "can start the LSP server", %{server: server} do
      assert alive?(server)
    end

    test "responds correctly to a shutdown request", %{client: client} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}

      assert :ok ==
               request(client, %{
                 method: "shutdown",
                 id: 2,
                 jsonrpc: "2.0"
               })

      assert_result 2, nil
    end

    test "returns method not found for unimplemented requests", %{client: client} do
      id = System.unique_integer([:positive])

      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert :ok ==
               request(client, %{
                 method: "textDocument/signatureHelp",
                 id: id,
                 jsonrpc: "2.0",
                 params: %{position: %{line: 0, character: 0}, textDocument: %{uri: ""}}
               })

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] Method Not Found: textDocument/signatureHelp",
        "type" => 2
      }

      assert_error ^id, %{
        "code" => -32_601,
        "message" => "Method Not Found: textDocument/signatureHelp"
      }
    end

    test "can initialize the server" do
      assert_result 1, %{
        "capabilities" => %{
          "textDocumentSync" => %{
            "openClose" => true,
            "save" => %{
              "includeText" => true
            },
            "change" => 1
          }
        },
        "serverInfo" => %{"name" => "Next LS"}
      }
    end

    test "publishes diagnostics once the client has initialized", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] NextLS v" <> _,
        "type" => 4
      }

      assert_notification "$/progress", %{
        "value" => %{"kind" => "begin", "title" => "Initializing NextLS runtime for folder my_proj..."}
      }

      assert_notification "$/progress", %{
        "value" => %{
          "kind" => "end",
          "message" => "NextLS runtime for folder my_proj has initialized!"
        }
      }

      assert_notification "$/progress", %{"value" => %{"kind" => "begin", "title" => "Compiling..."}}

      assert_notification "$/progress", %{
        "value" => %{
          "kind" => "end",
          "message" => "Compiled!"
        }
      }

      for file <- ["bar.ex"] do
        uri =
          to_string(%URI{
            host: "",
            scheme: "file",
            path: Path.join([cwd, "my_proj/lib", file])
          })

        char = if Version.match?(System.version(), ">= 1.15.0"), do: 10, else: 0

        assert_notification "textDocument/publishDiagnostics", %{
          "uri" => ^uri,
          "diagnostics" => [
            %{
              "source" => "Elixir",
              "severity" => 2,
              "message" =>
                "variable \"arg1\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
              "range" => %{
                "start" => %{"line" => 3, "character" => ^char},
                "end" => %{"line" => 3, "character" => 999}
              }
            }
          ]
        }
      end
    end

    test "formats", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      notify client, %{
        method: "textDocument/didOpen",
        jsonrpc: "2.0",
        params: %{
          textDocument: %{
            uri: "file://#{cwd}/my_proj/lib/foo/bar.ex",
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
            uri: "file://#{cwd}/my_proj/lib/foo/bar.ex"
          },
          options: %{
            insertSpaces: true,
            tabSize: 2
          }
        }
      }

      assert_result 2, nil

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}

      request client, %{
        method: "textDocument/formatting",
        id: 3,
        jsonrpc: "2.0",
        params: %{
          textDocument: %{
            uri: "file://#{cwd}/my_proj/lib/foo/bar.ex"
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

      assert_result 3, [
        %{
          "newText" => ^new_text,
          "range" => %{"start" => %{"character" => 0, "line" => 0}, "end" => %{"character" => 0, "line" => 8}}
        }
      ]
    end

    test "formatting gracefully handles files with syntax errors", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      notify client, %{
        method: "textDocument/didOpen",
        jsonrpc: "2.0",
        params: %{
          textDocument: %{
            uri: "file://#{cwd}/my_proj/lib/foo/bar.ex",
            languageId: "elixir",
            version: 1,
            text: """
            defmodule Foo.Bar do
              def run() do


                :ok
            end
            """
          }
        }
      }

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}

      request client, %{
        method: "textDocument/formatting",
        id: 2,
        jsonrpc: "2.0",
        params: %{
          textDocument: %{
            uri: "file://#{cwd}/my_proj/lib/foo/bar.ex"
          },
          options: %{
            insertSpaces: true,
            tabSize: 2
          }
        }
      }

      assert_result 2, nil
    end

    test "workspace symbols", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      request client, %{
        method: "workspace/symbol",
        id: 2,
        jsonrpc: "2.0",
        params: %{
          query: ""
        }
      }

      assert_result 2, symbols

      assert %{
               "kind" => 12,
               "location" => %{
                 "range" => %{
                   "start" => %{
                     "line" => 3,
                     "character" => 0
                   },
                   "end" => %{
                     "line" => 3,
                     "character" => 0
                   }
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/bar.ex"
               },
               "name" => "def foo"
             } in symbols

      assert %{
               "kind" => 2,
               "location" => %{
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
                 "uri" => "file://#{cwd}/my_proj/lib/bar.ex"
               },
               "name" => "defmodule Bar"
             } in symbols

      assert %{
               "kind" => 23,
               "location" => %{
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
                 "uri" => "file://#{cwd}/my_proj/lib/bar.ex"
               },
               "name" => "%Bar{}"
             } in symbols

      assert %{
               "kind" => 2,
               "location" => %{
                 "range" => %{
                   "start" => %{
                     "line" => 3,
                     "character" => 0
                   },
                   "end" => %{
                     "line" => 3,
                     "character" => 0
                   }
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/code_action.ex"
               },
               "name" => "defmodule Foo.CodeAction.NestedMod"
             } in symbols
    end

    test "workspace symbols with query", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      request client, %{
        method: "workspace/symbol",
        id: 2,
        jsonrpc: "2.0",
        params: %{
          query: "fo"
        }
      }

      assert_result 2, symbols

      assert [
               %{
                 "kind" => 12,
                 "location" => %{
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
                   "uri" => "file://#{cwd}/my_proj/lib/code_action.ex"
                 },
                 "name" => "def foo"
               },
               %{
                 "kind" => 12,
                 "location" => %{
                   "range" => %{
                     "start" => %{
                       "line" => 3,
                       "character" => 0
                     },
                     "end" => %{
                       "line" => 3,
                       "character" => 0
                     }
                   },
                   "uri" => "file://#{cwd}/my_proj/lib/bar.ex"
                 },
                 "name" => "def foo"
               }
             ] == symbols
    end

    test "deletes symbols when a file is deleted", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      request client, %{method: "workspace/symbol", id: 2, jsonrpc: "2.0", params: %{query: ""}}

      symbol = %{
        "kind" => 2,
        "location" => %{
          "range" => %{
            "start" => %{
              "line" => 3,
              "character" => 0
            },
            "end" => %{
              "line" => 3,
              "character" => 0
            }
          },
          "uri" => "file://#{cwd}/my_proj/lib/code_action.ex"
        },
        "name" => "defmodule Foo.CodeAction.NestedMod"
      }

      assert_result 2, symbols

      assert symbol in symbols

      notify(client, %{
        method: "workspace/didChangeWatchedFiles",
        jsonrpc: "2.0",
        params: %{
          changes: [
            %{
              type: GenLSP.Enumerations.FileChangeType.deleted(),
              uri: "file://#{Path.join(cwd, "my_proj/lib/code_action.ex")}"
            }
          ]
        }
      })

      request client, %{method: "workspace/symbol", id: 3, jsonrpc: "2.0", params: %{query: ""}}

      assert_result 3, symbols

      assert symbol not in symbols
    end
  end

  describe "function go to definition" do
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

    test "go to local function definition", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

    test "go to imported function definition", %{client: client, bar: bar, imported: imported} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

    test "go to remote function definition", %{client: client, bar: bar, remote: remote} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

  describe "macro go to definition" do
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

    test "go to imported macro definition", %{client: client, bar: bar, imported: imported} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

    test "go to remote macro definition", %{client: client, bar: bar, remote: remote} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

  describe "module go to definition" do
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

    test "go to module definition", %{client: client, bar: bar, peace: peace} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
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

  describe "find references" do
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

    test "list function references", %{client: client, bar: bar, peace: peace} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      request(client, %{
        method: "textDocument/references",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 1, character: 6},
          textDocument: %{uri: uri(peace)},
          context: %{includeDeclaration: true}
        }
      })

      uri = uri(bar)

      assert_result 4,
                    [
                      %{
                        "uri" => ^uri,
                        "range" => %{
                          "start" => %{"line" => 3, "character" => 10},
                          "end" => %{"line" => 3, "character" => 18}
                        }
                      }
                    ],
                    500
    end

    test "list module references", %{client: client, bar: bar, peace: peace} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder my_proj is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      request(client, %{
        method: "textDocument/references",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 0, character: 10},
          textDocument: %{uri: uri(peace)},
          context: %{includeDeclaration: true}
        }
      })

      uri = uri(bar)

      assert_result 4,
                    [
                      %{
                        "uri" => ^uri,
                        "range" => %{
                          "start" => %{"line" => 3, "character" => 4},
                          "end" => %{"line" => 3, "character" => 9}
                        }
                      }
                    ],
                    500
    end
  end

  describe "workspaces" do
    setup %{tmp_dir: tmp_dir} do
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
    test "starts a new runtime when you add a workspace folder", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_one is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      notify(client, %{
        method: "workspace/didChangeWorkspaceFolders",
        jsonrpc: "2.0",
        params: %{
          event: %{
            added: [
              %{name: "proj_two", uri: "file://#{Path.join(cwd, "proj_two")}"}
            ],
            removed: []
          }
        }
      })

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_two is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}
    end

    @tag root_paths: ["proj_one", "proj_two"]
    test "stops the runtime when you remove a workspace folder", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_one is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_two is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      notify(client, %{
        method: "workspace/didChangeWorkspaceFolders",
        jsonrpc: "2.0",
        params: %{
          event: %{
            added: [],
            removed: [
              %{name: "proj_two", uri: "file://#{Path.join(cwd, "proj_two")}"}
            ]
          }
        }
      })

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] The runtime for proj_two has successfully shutdown."
      }
    end

    @tag root_paths: ["proj_one"]
    test "can register for workspace/didChangedWatchedFiles", %{client: client} do
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

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_one is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}
    end

    @tag root_paths: ["proj_one"]
    test "can receive workspace/didChangeWatchedFiles notification", %{client: client, cwd: cwd} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_request(client, "client/registerCapability", fn _params -> nil end)

      assert_notification "window/logMessage", %{"message" => "[NextLS] Runtime for folder proj_one is ready..."}
      assert_notification "window/logMessage", %{"message" => "[NextLS] Compiled!"}

      notify(client, %{
        method: "workspace/didChangeWatchedFiles",
        jsonrpc: "2.0",
        params: %{changes: [%{type: 3, uri: "file://#{Path.join(cwd, "proj_one/lib/peace.ex")}"}]}
      })
    end
  end

  defp with_lsp(%{tmp_dir: tmp_dir} = context) do
    root_paths =
      for path <- context[:root_paths] || [""] do
        Path.absname(Path.join(tmp_dir, path))
      end

    tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: :one))
    r_tvisor = start_supervised!(Supervisor.child_spec(Task.Supervisor, id: :two))
    rvisor = start_supervised!({DynamicSupervisor, [strategy: :one_for_one]})
    start_supervised!({Registry, [keys: :duplicate, name: Registry.NextLSTest.Registry]})
    extensions = [NextLS.ElixirExtension]
    cache = start_supervised!(NextLS.DiagnosticCache)

    server =
      server(NextLS,
        task_supervisor: tvisor,
        runtime_task_supervisor: r_tvisor,
        dynamic_supervisor: rvisor,
        registry: Registry.NextLSTest.Registry,
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
                 workspaceFolders: for(path <- root_paths, do: %{uri: "file://#{path}", name: Path.basename(path)})
               }
             })

    [server: server, client: client]
  end

  defp uri(path) when is_binary(path) do
    URI.to_string(%URI{
      scheme: "file",
      host: "",
      path: path
    })
  end
end
