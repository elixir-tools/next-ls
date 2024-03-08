defmodule NextLSTest do
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

  test "responds correctly to a shutdown request", %{client: client} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")

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

    assert :ok ==
             request(client, %{
               method: "textDocument/signatureHelp",
               id: id,
               jsonrpc: "2.0",
               params: %{position: %{line: 0, character: 0}, textDocument: %{uri: ""}}
             })

    assert_notification "window/logMessage", %{
      "message" => "[Next LS] Method Not Found: textDocument/signatureHelp",
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

  test "formats", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    did_open(client, Path.join(cwd, "my_proj/lib/foo/bar.ex"), """
    defmodule Foo.Bar do
      def run() do


        :ok
      end
    end
    """)

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

    assert_is_ready(context, "my_proj")

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

  test "formatting gracefully handles files with syntax errors", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    did_open(client, Path.join(cwd, "my_proj/lib/foo/bar.ex"), """
    defmodule Foo.Bar do
      def run() do


        :ok
    end
    """)

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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

  test "workspace symbols", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
                   "character" => 6
                 },
                 "end" => %{
                   "line" => 3,
                   "character" => 6
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

  test "workspace symbols with query", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    request client, %{
      method: "workspace/symbol",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        query: "Project"
      }
    }

    assert_result 2, symbols

    assert [
             %{
               "kind" => 2,
               "location" => %{
                 "range" => %{
                   "end" => %{"character" => 0, "line" => 0},
                   "start" => %{"character" => 0, "line" => 0}
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/project.ex"
               },
               "name" => "defmodule Project"
             }
           ] == symbols
  end

  test "workspace symbols with query fuzzy search", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    request client, %{
      method: "workspace/symbol",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        query: "heo"
      }
    }

    assert_result 2, symbols

    assert [
             %{
               "kind" => 12,
               "location" => %{
                 "range" => %{
                   "end" => %{"character" => 6, "line" => 1},
                   "start" => %{"character" => 6, "line" => 1}
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/project.ex"
               },
               "name" => "def hello"
             }
           ] == symbols
  end

  test "workspace symbols with query case sensitive fuzzy search", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    request client, %{
      method: "workspace/symbol",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        query: "Ct"
      }
    }

    assert_result 2, symbols

    assert [
             %{
               "kind" => 2,
               "location" => %{
                 "range" => %{
                   "end" => %{"character" => 0, "line" => 3},
                   "start" => %{"character" => 0, "line" => 3}
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/code_action.ex"
               },
               "name" => "defmodule Foo.CodeAction.NestedMod"
             },
             %{
               "kind" => 2,
               "location" => %{
                 "range" => %{
                   "end" => %{"character" => 0, "line" => 0},
                   "start" => %{"character" => 0, "line" => 0}
                 },
                 "uri" => "file://#{cwd}/my_proj/lib/code_action.ex"
               },
               "name" => "defmodule Foo.CodeAction"
             }
           ] == symbols
  end

  test "deletes symbols when a file is deleted", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

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
