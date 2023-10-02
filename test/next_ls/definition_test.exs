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
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
      assert_compiled(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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

      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
      defmodule Bar.Bell do
        alias MyApp.Peace
        def run() do
          Peace.and_love()
        end
      end
      """)

      baz = Path.join(cwd, "my_proj/lib/baz.ex")

      File.write!(baz, """
      defmodule Baz do
        alias Bar.Bell
        alias MyApp.{
          Peace
        }
        def run() do
          Peace.and_love()
        end
      end
      """)

      [bar: bar, peace: peace, baz: baz]
    end

    setup :with_lsp

    test "go to module definition", %{client: client, bar: bar, peace: peace} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_is_ready(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
                        "start" => %{"line" => 0, "character" => 0},
                        "end" => %{"line" => 0, "character" => 0}
                      },
                      "uri" => ^uri
                    },
                    500
    end

    test "go to module alias definition", %{client: client, peace: peace, bar: bar, baz: baz} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_is_ready(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(baz)

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
                        "start" => %{"line" => 0, "character" => 0},
                        "end" => %{"line" => 0, "character" => 0}
                      },
                      "uri" => ^uri
                    },
                    500

      uri = uri(baz)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 1, character: 10},
          textDocument: %{uri: uri}
        }
      })

      uri = uri(bar)

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{"line" => 0, "character" => 0},
                        "end" => %{"line" => 0, "character" => 0}
                      },
                      "uri" => ^uri
                    },
                    500
    end
  end

  describe "attribute" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Bar do
        @my_attr 1
        @second_attr 2

        @spec run() :: :ok | :error
        def run() do
          if @my_attr == 1 do
            :ok
          else
            {:error, @second_attr}
          end
        end

        defmodule Inner do
          @inner_attr 123

          def foo(a) do
            if a, do: @inner_attr
          end
        end

        def foo() do
          :nothing
        end
      end

      defmodule TopSecond.Some.Long.Name do
        @top_second_attr "something"

        def run_second do
          {:error, @top_second_attr}
        end
      end
      """)

      [bar: bar]
    end

    setup :with_lsp

    test "go to attribute definition", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 6, character: 9},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{
                          "line" => 1,
                          "character" => 2
                        },
                        "end" => %{
                          "line" => 1,
                          "character" => 2
                        }
                      },
                      "uri" => ^uri
                    },
                    500
    end

    test "go to attribute definition in second module", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 30, character: 17},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{
                          "line" => 27,
                          "character" => 2
                        },
                        "end" => %{
                          "line" => 27,
                          "character" => 2
                        }
                      },
                      "uri" => ^uri
                    },
                    500
    end

    test "go to attribute definition in inner module", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 17, character: 20},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{
                          "line" => 14,
                          "character" => 4
                        },
                        "end" => %{
                          "line" => 14,
                          "character" => 4
                        }
                      },
                      "uri" => ^uri
                    },
                    500
    end
  end

  describe "local variables" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Bar do
        @my_attr 1

        def run({:ok, alpha} = bravo) do
          if @my_attr == 1 do
            charlie = "Something: " <> alpha

            {:ok, charlie}
          else
            bravo
          end
        end
      end
      """)

      [bar: bar]
    end

    setup :with_lsp

    test "go to local variable definition", %{client: client, bar: bar} do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_request(client, "client/registerCapability", fn _params -> nil end)
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/definition",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 7, character: 12},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4,
                    %{
                      "range" => %{
                        "start" => %{
                          "line" => 5,
                          "character" => 6
                        },
                        "end" => %{
                          "line" => 5,
                          "character" => 12
                        }
                      },
                      "uri" => ^uri
                    },
                    500
    end
  end
end
