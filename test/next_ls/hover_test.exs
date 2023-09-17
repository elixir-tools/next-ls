defmodule NextLS.HoverTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]
  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())

    cwd = Path.join(tmp_dir, "my_proj")
    File.mkdir_p!(Path.join([cwd, "lib", "bar"]))
    baz = Path.join(cwd, "lib/bar/baz.ex")

    File.write!(baz, """
    defmodule Bar.Baz do
      @moduledoc "Bar.Baz module"
      @doc "Bar.Baz.q function"
      def q do
        "q"
      end
    end
    """)

    fiz = Path.join(cwd, "lib/bar/fiz.ex")

    File.write!(fiz, """
    defmodule Bar.Fiz do
      # No doc
      def q do
        "q"
      end
    end
    """)

    guz = Path.join(cwd, "lib/bar/guz.ex")

    File.write!(guz, """
    defmodule Bar.Guz do
      alias Foo.Bar
      alias Bar.Baz
      @moduledoc "Bar.Guz module"
      @doc "Bar.Guz.q function"
      def q do
        "q"
      end
    end
    """)

    foo = Path.join(cwd, "lib/foo.ex")

    File.write!(foo, """
    defmodule Foo do
      @moduledoc "Foo module"
      @doc "Foo.bar function"
      def bar do
        "baz"
      end
    end
    """)

    example = Path.join(cwd, "lib/example.ex")

    File.write!(example, """
    defmodule Example do
      @moduledoc "Example doc"
      alias Foo, as: Foz
      alias Bar.{
        Fiz,
        Baz
      }
      alias Bar.Guz
      defstruct [:foo]
      def test do
        q1 = Atom.to_string(:atom)
        q2 = Foz.bar()
        q3 = Baz.q()
        q4 = Fiz.q()
        q5 = Guz.q()
        q6 = to_string(:abs)
        :timer.sleep(1)
        q7 = %Example{foo: "a"}
        [q1] ++ [q2] ++ [q3] ++ [q4] ++ [q5] ++ [q6] ++ [q7.foo]
      end
    end
    """)

    [example: example]
  end

  setup :with_lsp

  setup context do
    assert :ok == notify(context.client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_request(context.client, "client/registerCapability", fn _params -> nil end)
    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}
  end

  test "alias calls", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 2, character: 18},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 2,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Foo\n\nFoo module"
                    },
                    "range" => %{
                      "start" => %{"character" => 17, "line" => 2},
                      "end" => %{"character" => 19, "line" => 2}
                    }
                  },
                  500

    request client, %{
      method: "textDocument/hover",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 5, character: 5},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 4,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Bar.Baz\n\nBar.Baz module"
                    },
                    "range" => %{
                      "start" => %{"character" => 4, "line" => 5},
                      "end" => %{"character" => 6, "line" => 5}
                    }
                  },
                  500
  end

  test "modules", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 2,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 11, character: 10},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 2,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Foo\n\nFoo module"
                    },
                    "range" => %{
                      "start" => %{"line" => 11, "character" => 9},
                      "end" => %{"line" => 11, "character" => 11}
                    }
                  },
                  500
  end

  # TODO: this was fixed recently, will emit the elixir docs
  test "inlined function", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 7,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 10, character: 18},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 7,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" =>
                        "## :erlang.atom_to_binary/1\n\n" <>
                          _
                    },
                    "range" => %{
                      "start" => %{"character" => 14, "line" => 10},
                      "end" => %{"character" => 27, "line" => 10}
                    }
                  },
                  500
  end

  test "elixir function", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 8,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 12, character: 13},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 8,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Bar.Baz.q/0\n\nBar.Baz.q function"
                    },
                    "range" => %{
                      "start" => %{"character" => 13, "line" => 12},
                      "end" => %{"character" => 13, "line" => 12}
                    }
                  },
                  500
  end

  test "module without docs", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 9,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 13, character: 11},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 9, nil, 500
  end

  test "function without docs", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 10,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 13, character: 13},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 10, nil, 500
  end

  test "imported function", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 11,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 15, character: 12},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 11,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Kernel.to_string/1\n\nConverts the argument to a string" <> _
                    },
                    "range" => %{
                      "start" => %{"character" => 9, "line" => 15},
                      "end" => %{"character" => 17, "line" => 15}
                    }
                  },
                  500
  end

  test "erlang function", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 13,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 16, character: 13},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 13,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" =>
                        "## :timer.sleep/1\n\nSuspends the process" <>
                          _
                    },
                    "range" => %{
                      "start" => %{"character" => 11, "line" => 16},
                      "end" => %{"character" => 15, "line" => 16}
                    }
                  },
                  500
  end

  test "structs", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 14,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 17, character: 13},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 14,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Example\n\nExample doc"
                    },
                    "range" => %{
                      "start" => %{"character" => 10, "line" => 17},
                      "end" => %{"character" => 16, "line" => 17}
                    }
                  },
                  500
  end

  test "imported macro", %{client: client, example: example} do
    example_uri = uri(example)

    request client, %{
      method: "textDocument/hover",
      id: 15,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 9, character: 3},
        textDocument: %{uri: example_uri}
      }
    }

    assert_result 15,
                  %{
                    "contents" => %{
                      "kind" => "markdown",
                      "value" => "## Kernel.def/2\n\nDefines a public function with the given name and body" <> _
                    },
                    "range" => %{
                      "start" => %{"character" => 2, "line" => 9},
                      "end" => %{"character" => 4, "line" => 9}
                    }
                  },
                  500
  end
end
