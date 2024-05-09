defmodule NextLS.CompletionsTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag init_options: %{"experimental" => %{"completions" => %{"enable" => true}}}

  defmacrop assert_match({:in, _, [left, right]}) do
    quote do
      assert Enum.any?(unquote(right), fn x ->
               match?(unquote(left), x)
             end),
             """
             failed to find a match inside of list

             left: #{unquote(Macro.to_string(left))}
             right: #{inspect(unquote(right), pretty: true)}
             """
    end
  end

  defmacrop assert_match({:not, _, [{:in, _, [left, right]}]}) do
    quote do
      refute Enum.any?(unquote(right), fn x ->
               match?(unquote(left), x)
             end),
             """
             found a match inside of list, expected none

             left: #{unquote(Macro.to_string(left))}
             right: #{inspect(unquote(right), pretty: true)}
             """
    end
  end

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

    baz = Path.join(cwd, "my_proj/lib/baz.ex")

    File.write!(baz, """
    defmodule Foo.Bing.Baz do
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

    assert_result 2, [_, _, _] = results

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
             "insertText" => "baz.ex",
             "kind" => 17,
             "label" => "baz.ex"
           } in results

    assert %{
             "data" => nil,
             "documentation" => "",
             "insertText" => "foo.ex",
             "kind" => 17,
             "label" => "foo.ex"
           } in results
  end

  test "inside interpolation in strings", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, ~S"""
    defmodule Foo do
      def run(thing) do
        "./lib/#{t}"
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
          character: 13
        }
      }
    }

    assert_result 2, results

    assert %{
             "data" => nil,
             "documentation" => "",
             "insertText" => "thing",
             "kind" => 6,
             "label" => "thing"
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

    assert_result 2, results

    assert_match %{
                   "insertText" => "defmodule ${1:Foo} do\n  $0\nend\n",
                   "kind" => 15,
                   "label" => "defmodule/2",
                   "insertTextFormat" => 2
                 } in results
  end

  test "aliases in document", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      alias Foo.Bing

      def run() do
        B
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
          line: 4,
          character: 5
        }
      }
    }

    assert_result 2, results

    assert_match %{"data" => _, "insertText" => "Bing", "kind" => 9, "label" => "Bing"} in results
  end

  test "inside alias special form", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      alias Foo.Bing.

      def run() do
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
          line: 1,
          character: 16
        }
      }
    }

    assert_result 2, [
      %{"data" => _, "documentation" => _, "insertText" => "Bing", "kind" => 9, "label" => "Bing"}
    ]
  end

  test "import functions appear", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      use ExUnit.Case
      import ExUnit.CaptureLog

      test "foo" do
        cap
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
          line: 5,
          character: 7
        }
      }
    }

    assert_result 2, results

    assert_match(
      %{"data" => _, "documentation" => _, "insertText" => "capture_log", "kind" => 3, "label" => "capture_log/1"} in results
    )

    assert_match(
      %{"data" => _, "documentation" => _, "insertText" => "capture_log", "kind" => 3, "label" => "capture_log/2"} in results
    )
  end

  test "completions inside generator rhs", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run() do
        var = "hi"

        for thing <- v do
        end

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
          line: 4,
          character: 18
        }
      }
    }

    assert_result 2, [
      %{
        "data" => _,
        "documentation" => "",
        "insertText" => "var",
        "kind" => 6,
        "label" => "var"
      },
      %{
        "data" => _,
        "documentation" => _,
        "insertText" => "var!",
        "kind" => 3,
        "label" => "var!/1"
      },
      %{
        "data" => _,
        "documentation" => _,
        "insertText" => "var!",
        "kind" => 3,
        "label" => "var!/2"
      }
    ]
  end

  test "variable and param completions", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run(%Bar{one: %{foo: %{bar: villain}}, two: vim}, vroom) do
        document = vroom.assigns.documents[vim]
        v
      rescue
        _ ->
          :error
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
          line: 3,
          character: 5
        }
      }
    }

    assert_result 2, results

    # assert_match %{"kind" => 6, "label" => "vampire"} in results
    assert_match %{"kind" => 6, "label" => "villain"} in results
    assert_match %{"kind" => 6, "label" => "vim"} in results
    # assert_match %{"kind" => 6, "label" => "vrest"} in results
    assert_match %{"kind" => 6, "label" => "vroom"} in results
    # assert_match %{"kind" => 6, "label" => "var"} in results
  end

  test "variable and param completions in other block identifiers", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run(%Bar{one: %{foo: %{bar: villain}}, two: vim}, vroom) do
        var1 = vroom.assigns.documents[vim]
        v
      rescue
        verror ->
          var2 = "hi"

          v
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
          line: 8,
          character: 7
        }
      }
    }

    assert_result 2, results

    assert_match %{"kind" => 6, "label" => "villain"} in results
    assert_match %{"kind" => 6, "label" => "vim"} in results
    assert_match %{"kind" => 6, "label" => "vroom"} in results
    assert_match %{"kind" => 6, "label" => "verror"} in results
    assert_match %{"kind" => 6, "label" => "var2"} in results

    assert_match %{"kind" => 6, "label" => "var1"} not in results
  end

  test "param completions in multi arrow situations", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run(alice) do
        alice
        |> then(fn
          {:ok, ast1} -> ast1
          {:error, ast2, _} -> a
          {:error, :no_fuel_remaining} -> nil
        end)
      end
    end
    """)

    request client, %{
      method: "textDocument/completion",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        textDocument: %{uri: uri},
        position: %{
          line: 5,
          character: 28
        }
      }
    }

    assert_result 2, results

    assert_match %{"kind" => 6, "label" => "alice"} in results
    # TODO: requires changes to spitfire
    # assert_match %{"kind" => 6, "label" => "ast2"} in results

    assert_match %{"kind" => 6, "label" => "ast1"} not in results
  end

  test "variables show up in test blocks", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      use ExUnit.Case
      test "something", %{vim: vim} do
        var = "hi"

        v
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
          line: 5,
          character: 5
        }
      }
    }

    assert_result 2, results

    assert_match %{"kind" => 6, "label" => "var"} in results
    assert_match %{"kind" => 6, "label" => "vim"} in results
  end

  test "<- matches dont leak from for", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run(items) do
        names = 
          for item <- items do
            item.name
          end

        i
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
          line: 7,
          character: 5
        }
      }
    }

    assert_result 2, results

    assert_match %{"kind" => 6, "label" => "items"} in results
    assert_match %{"kind" => 6, "label" => "item"} not in results
  end

  test "<- matches dont leak from with", %{client: client, foo: foo} do
    uri = uri(foo)

    did_open(client, foo, """
    defmodule Foo do
      def run(items) do
        names = 
          with item <- items do
            item.name
          end

        i
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
          line: 7,
          character: 5
        }
      }
    }

    assert_result 2, results

    assert_match %{"kind" => 6, "label" => "items"} in results
    assert_match %{"kind" => 6, "label" => "item"} not in results
  end
end
