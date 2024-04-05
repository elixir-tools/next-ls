defmodule NextLS.CompletionsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
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

    bar = Path.join(cwd, "my_proj/lib/bar.ex")

    File.write!(bar, """
    defmodule Bar do
      defstruct [:one, :two, :three]
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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        En
        :ok
      end
    end
    """)

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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        Enum.fl
        :ok
      end
    end
    """)

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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        %U
        :ok
      end
    end
    """)

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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        IO.inspect([%Bar{])
        :ok
      end
    end
    """)

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
      %{"data" => nil, "documentation" => "", "insertText" => "one", "kind" => 5, "label" => "one"},
      %{"data" => nil, "documentation" => "", "insertText" => "two", "kind" => 5, "label" => "two"},
      %{"data" => nil, "documentation" => "", "insertText" => "three", "kind" => 5, "label" => "three"}
    ]
  end

  test "special forms", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        qu
        :ok
      end
    end
    """)

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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        <<one::
        :ok
      end
    end
    """)

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

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        "./lib/
        :ok
      end
    end
    """)

    {results, log} =
      with_log(fn ->
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

        assert_result 2, [_, _] = results
        results
      end)

    assert log =~ "Could not locate cursor"
    assert log =~ "Source code that produced the above warning:"

    assert %{
             "data" => nil,
             "documentation" => "",
             "insertText" => "bar.ex",
             "kind" => 17,
             "label" => "bar.ex"
           } in results

    assert %{
             "data" => nil,
             "documentation" => "",
             "insertText" => "foo.ex",
             "kind" => 17,
             "label" => "foo.ex"
           } in results
  end

  test "defmodule infer name", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmod
    """)

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{
          uri: uri
        },
        position: %{
          line: 0,
          character: 6
        }
      }
    }

    assert_result 2, [
      %{
        "data" => nil,
        "documentation" => _,
        "insertText" => "defmodule ${1:Foo} do\n  $0\nend\n",
        "kind" => 15,
        "label" => "defmodule/2",
        "insertTextFormat" => 2
      }
    ]
  end
end
