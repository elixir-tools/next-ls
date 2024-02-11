defmodule NextLS.DependencyTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), proj_mix_exs())

    File.mkdir_p!(Path.join(tmp_dir, "bar/lib"))
    File.write!(Path.join(tmp_dir, "bar/mix.exs"), bar_mix_exs())

    File.mkdir_p!(Path.join(tmp_dir, "baz/lib"))
    File.write!(Path.join(tmp_dir, "baz/mix.exs"), baz_mix_exs())

    [cwd: tmp_dir]
  end

  setup %{cwd: cwd} do
    foo = Path.join(cwd, "my_proj/lib/foo.ex")

    File.write!(foo, """
    defmodule Foo do
      def foo() do
        Bar.bar()
        Baz
      end

      def call_baz() do
        Baz.baz()
      end
    end
    """)

    cache = Path.join(cwd, "my_proj/lib/cache.ex")

    File.write!(cache, """
    defmodule Cache do
      use GenServer

      def init(_) do
        {:ok, nil}
      end

      def get() do
        GenServer.call(__MODULE__, :get)
      end
    end
    """)

    bar = Path.join(cwd, "bar/lib/bar.ex")

    File.write!(bar, """
    defmodule Bar do
      def bar() do
        42
      end
    end
    """)

    baz = Path.join(cwd, "baz/lib/baz.ex")

    File.write!(baz, """
    defmodule Baz do
      def baz() do
        42
      end
    end
    """)

    [foo: foo, bar: bar, baz: baz, cache: cache]
  end

  setup :with_lsp

  test "go to dependency function definition", context do
    %{client: client, foo: foo, bar: bar} = context

    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    uri = uri(foo)

    request(client, %{
      method: "textDocument/definition",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 2, character: 9},
        textDocument: %{uri: uri}
      }
    })

    uri = uri(bar)

    assert_result 4, %{
      "range" => %{
        "start" => %{
          "line" => 1,
          "character" => 6
        },
        "end" => %{
          "line" => 1,
          "character" => 6
        }
      },
      "uri" => ^uri
    }
  end

  test "does not show in workspace symbols", context do
    %{client: client, foo: foo, bar: bar} = context
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

    uris = Enum.map(symbols, fn result -> result["location"]["uri"] end)
    assert uri(foo) in uris
    refute uri(bar) in uris
  end

  test "does not show up in function references", %{client: client, foo: foo} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    uri = uri(foo)

    request(client, %{
      method: "textDocument/references",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 7, character: 8},
        textDocument: %{uri: uri},
        context: %{includeDeclaration: true}
      }
    })

    assert_result2(
      4,
      [
        %{
          "range" => %{"start" => %{"character" => 8, "line" => 7}, "end" => %{"character" => 10, "line" => 7}},
          "uri" => uri
        }
      ]
    )
  end

  test "does not show up in module references", %{client: client, foo: foo} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    uri = uri(foo)

    request(client, %{
      method: "textDocument/references",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 3, character: 4},
        textDocument: %{uri: uri},
        context: %{includeDeclaration: true}
      }
    })

    assert_result2(
      4,
      [
        %{
          "range" => %{"start" => %{"character" => 4, "line" => 3}, "end" => %{"character" => 6, "line" => 3}},
          "uri" => uri
        },
        %{
          "range" => %{"start" => %{"character" => 4, "line" => 7}, "end" => %{"character" => 6, "line" => 7}},
          "uri" => uri
        }
      ]
    )
  end

  test "elixir source files do not show up in references", %{client: client, cache: cache} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")

    assert_notification "$/progress", %{
      "value" => %{"kind" => "end", "message" => "Compiled Elixir.NextLS.DependencyTest-my_proj!"}
    }

    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    uri = uri(cache)

    request(client, %{
      method: "textDocument/references",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 8, character: 6},
        textDocument: %{uri: uri},
        context: %{includeDeclaration: true}
      }
    })

    assert_result2(
      4,
      [
        %{
          "range" => %{"end" => %{"character" => 14, "line" => 1}, "start" => %{"character" => 6, "line" => 1}},
          "uri" => uri
        },
        %{
          "range" => %{"end" => %{"character" => 12, "line" => 8}, "start" => %{"character" => 4, "line" => 8}},
          "uri" => uri
        }
      ]
    )
  end

  defp proj_mix_exs do
    """
    defmodule MyProj.MixProject do
      use Mix.Project

      def project do
        [
          app: :my_proj,
          version: "0.1.0",
          elixir: "~> 1.10",
          deps: [
            {:bar, path: "../bar"},
          ]
        ]
      end
    end
    """
  end

  defp bar_mix_exs do
    """
    defmodule Bar.MixProject do
      use Mix.Project

      def project do
        [
          app: :bar,
          version: "0.1.0",
          elixir: "~> 1.10",
          deps: [
            {:baz, path: "../baz"}
          ]
        ]
      end
    end
    """
  end

  defp baz_mix_exs do
    """
    defmodule Baz.MixProject do
      use Mix.Project

      def project do
        [
          app: :baz,
          version: "0.1.0",
          elixir: "~> 1.10",
          deps: []
        ]
      end
    end
    """
  end
end
