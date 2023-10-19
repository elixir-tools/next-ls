defmodule NextLS.CompletionsTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag tmp_dir: true, root_paths: ["my_proj"]

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
    cwd = tmp_dir

    foo = Path.join(cwd, "my_proj/lib/foo.ex")

    File.write!(foo, """
    defmodule Foo do
      def run() do

        :ok
      end
    end
    """)

    [foo: foo, cwd: cwd]
  end

  setup :with_lsp

  setup %{client: client} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    :ok
  end

  test "global modules", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              En
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 6
        }
      }
    }

    assert_result 2, [
      %{"data" => _, "documentation" => _, "insertText" => "Enum", "kind" => 9, "label" => "Enum"},
      %{"data" => _, "documentation" => _, "insertText" => "Enumerable", "kind" => 9, "label" => "Enumerable"}
    ]
  end

  test "global module remote functions", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              Enum.fl
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 11
        }
      }
    }

    assert_result 2, [
      %{"data" => _, "documentation" => _, "insertText" => "flat_map", "kind" => 3, "label" => "flat_map/2"},
      %{
        "data" => _,
        "documentation" => _,
        "insertText" => "flat_map_reduce",
        "kind" => 3,
        "label" => "flat_map_reduce/3"
      }
    ]
  end

  test "global structs", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              %U
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 6
        }
      }
    }

    assert_result 2, [%{"data" => _, "documentation" => _, "insertText" => "URI", "kind" => 22, "label" => "URI"}]
  end

  test "structs fields", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              IO.inspect([%URI{])
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 21
        }
      }
    }

    assert_result 2, [
      %{"data" => nil, "documentation" => "", "insertText" => "port", "kind" => 5, "label" => "port"},
      %{"data" => nil, "documentation" => "", "insertText" => "scheme", "kind" => 5, "label" => "scheme"},
      %{"data" => nil, "documentation" => "", "insertText" => "path", "kind" => 5, "label" => "path"},
      %{"data" => nil, "documentation" => "", "insertText" => "host", "kind" => 5, "label" => "host"},
      %{"data" => nil, "documentation" => "", "insertText" => "userinfo", "kind" => 5, "label" => "userinfo"},
      %{"data" => nil, "documentation" => "", "insertText" => "fragment", "kind" => 5, "label" => "fragment"},
      %{"data" => nil, "documentation" => "", "insertText" => "query", "kind" => 5, "label" => "query"},
      %{"data" => nil, "documentation" => "", "insertText" => "authority", "kind" => 5, "label" => "authority"}
    ]
  end

  test "special forms", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              qu
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 6
        }
      }
    }

    assert_result 2, [%{"data" => _, "documentation" => _, "insertText" => "quote", "kind" => 3, "label" => "quote/2"}]
  end

  test "bitstring modifiers", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              <<one::
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 11
        }
      }
    }

    assert_result 2, [
      %{"data" => nil, "documentation" => "", "insertText" => "big", "kind" => 6, "label" => "big"},
      %{"data" => nil, "documentation" => "", "insertText" => "binary", "kind" => 6, "label" => "binary"},
      %{"data" => nil, "documentation" => "", "insertText" => "bitstring", "kind" => 6, "label" => "bitstring"},
      %{"data" => nil, "documentation" => "", "insertText" => "integer", "kind" => 6, "label" => "integer"},
      %{"data" => nil, "documentation" => "", "insertText" => "float", "kind" => 6, "label" => "float"},
      %{"data" => nil, "documentation" => "", "insertText" => "little", "kind" => 6, "label" => "little"},
      %{"data" => nil, "documentation" => "", "insertText" => "native", "kind" => 6, "label" => "native"},
      %{"data" => nil, "documentation" => "", "insertText" => "signed", "kind" => 6, "label" => "signed"},
      %{"data" => nil, "insertText" => "size", "kind" => 3, "label" => "size/1"},
      %{"data" => nil, "insertText" => "unit", "kind" => 3, "label" => "unit/1"},
      %{"data" => nil, "documentation" => "", "insertText" => "unsigned", "kind" => 6, "label" => "unsigned"},
      %{"data" => nil, "documentation" => "", "insertText" => "utf8", "kind" => 6, "label" => "utf8"},
      %{"data" => nil, "documentation" => "", "insertText" => "utf16", "kind" => 6, "label" => "utf16"},
      %{"data" => nil, "documentation" => "", "insertText" => "utf32", "kind" => 6, "label" => "utf32"}
    ]
  end

  test "file system paths in strings", %{client: client, foo: foo} do
    uri = uri(foo)

    notify client, %{
      method: "textDocument/didOpen",
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri,
          languageId: "elixir",
          version: 1,
          text: """
          defmodule Foo do
            def run() do
              "./lib/
              :ok
            end
          end
          """
        }
      }
    }

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 2,
          character: 11
        }
      }
    }

    assert_result 2, [
      %{
        "data" => nil,
        "documentation" => "",
        "insertText" => "next_ls.ex",
        "kind" => 17,
        "label" => "next_ls.ex"
      },
      %{
        "data" => nil,
        "documentation" => "",
        "insertText" => "next_ls/",
        "kind" => 19,
        "label" => "next_ls/"
      }
    ]
  end
end
