defmodule NextLS.Extensions.ElixirExtension.CodeActionTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())

    cwd = Path.join(tmp_dir, "my_proj")

    foo_path = Path.join(cwd, "lib/foo.ex")
    bar_path = Path.join(cwd, "lib/bar.ex")

    foo = """
    defmodule MyProj.Foo do
      def hello() do
        foo = :bar
        :world
      end

      def world() do
        Logger.info("no require")
      end
    end
    """

    bar = """
    defmodule MyProj.Bar do
      def foo() do
        a = :bar
        foo(dbg(a), IO.inspect(a))
        a
      end
    end
    """

    File.write!(foo_path, foo)
    File.write!(bar_path, bar)

    [foo: foo, foo_path: foo_path, bar: bar, bar_path: bar_path]
  end

  setup :with_lsp

  setup context do
    assert :ok == notify(context.client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    did_open(context.client, context.foo_path, context.foo)
    did_open(context.client, context.bar_path, context.bar)
    context
  end

  test "sends back a list of code actions", %{client: client, foo_path: foo} do
    foo_uri = uri(foo)
    id = 1

    request client, %{
      method: "textDocument/codeAction",
      id: id,
      jsonrpc: "2.0",
      params: %{
        context: %{
          "diagnostics" => [
            %{
              "data" => %{"namespace" => "elixir", "type" => "unused_variable"},
              "message" =>
                "variable \"foo\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
              "range" => %{"end" => %{"character" => 999, "line" => 3}, "start" => %{"character" => 4, "line" => 3}},
              "severity" => 2,
              "source" => "Elixir"
            }
          ]
        },
        range: %{start: %{line: 2, character: 4}, end: %{line: 2, character: 999}},
        textDocument: %{uri: foo_uri}
      }
    }

    assert_receive %{
                     "jsonrpc" => "2.0",
                     "id" => 1,
                     "result" => [%{"edit" => %{"changes" => %{^foo_uri => [%{"newText" => "_"}]}}}]
                   },
                   500
  end

  test "can send more than one code action", %{client: client, foo_path: foo} do
    foo_uri = uri(foo)
    id = 1

    request client, %{
      method: "textDocument/codeAction",
      id: id,
      jsonrpc: "2.0",
      params: %{
        context: %{
          "diagnostics" => [
            %{
              "data" => %{"namespace" => "elixir", "type" => "unused_variable"},
              "message" =>
                "variable \"foo\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
              "range" => %{"end" => %{"character" => 999, "line" => 2}, "start" => %{"character" => 4, "line" => 2}},
              "severity" => 2,
              "source" => "Elixir"
            },
            %{
              "data" => %{"namespace" => "elixir", "type" => "require"},
              "message" => "you must require Logger before invoking the macro Logger.info/1",
              "range" => %{"end" => %{"character" => 999, "line" => 7}, "start" => %{"character" => 0, "line" => 7}},
              "severity" => 2,
              "source" => "Elixir"
            }
          ]
        },
        range: %{start: %{line: 2, character: 0}, end: %{line: 7, character: 999}},
        textDocument: %{uri: foo_uri}
      }
    }

    assert_receive %{
                     "jsonrpc" => "2.0",
                     "id" => 1,
                     "result" => [
                       %{"edit" => %{"changes" => %{^foo_uri => [%{"newText" => "_"}]}}},
                       %{"edit" => %{"changes" => %{^foo_uri => [%{"newText" => "  require Logger\n"}]}}}
                     ]
                   },
                   500
  end

  test "sends back a remove inspect action", %{client: client, bar_path: bar} do
    bar_uri = uri(bar)
    id = 1

    request client, %{
      method: "textDocument/codeAction",
      id: id,
      jsonrpc: "2.0",
      params: %{
        context: %{
          "diagnostics" => [
            %{
              "data" => %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.Dbg"},
              "message" => "There should be no calls to `dbg/1`.",
              "range" => %{"end" => %{"character" => 13, "line" => 3}, "start" => %{"character" => 8, "line" => 3}},
              "severity" => 2,
              "source" => "Elixir"
            },
            %{
              "data" => %{"namespace" => "credo", "check" => "Elixir.Credo.Check.Warning.IoInspect"},
              "message" => "There should be no calls to `IO.inspect/1`.",
              "range" => %{"end" => %{"character" => 28, "line" => 3}, "start" => %{"character" => 20, "line" => 3}},
              "severity" => 2,
              "source" => "Elixir"
            }
          ]
        },
        range: %{start: %{line: 0, character: 0}, end: %{line: 7, character: 999}},
        textDocument: %{uri: bar_uri}
      }
    }

    assert_receive %{
                     "jsonrpc" => "2.0",
                     "id" => 1,
                     "result" => [
                       %{"edit" => %{"changes" => %{^bar_uri => [%{"newText" => "a", "range" => range1}]}}},
                       %{"edit" => %{"changes" => %{^bar_uri => [%{"newText" => "a", "range" => range2}]}}}
                     ]
                   },
                   500

    assert %{"start" => %{"character" => 8, "line" => 3}, "end" => %{"character" => 14, "line" => 3}} == range1
    assert %{"start" => %{"character" => 16, "line" => 3}, "end" => %{"character" => 29, "line" => 3}} == range2
  end
end
