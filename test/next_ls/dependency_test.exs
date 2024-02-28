defmodule NextLS.DependencyTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir

  describe "refetching deps" do
    @describetag root_paths: ["my_proj"]

    setup %{tmp_dir: cwd} do
      mixexs = Path.join(cwd, "my_proj/mix.exs")
      File.mkdir_p!(Path.join(cwd, "my_proj/lib"))

      File.write!(
        mixexs,
        proj_mix_exs("""
        [{:temple, "~> 0.11.0"}]
        """)
      )

      foo = Path.join(cwd, "my_proj/lib/foo.ex")

      File.write!(foo, """
      defmodule Foo do
        def foo, do: :ok
      end
      """)

      lockfile = Path.join(cwd, "my_proj/mix.lock")

      [cwd: cwd, foo: foo, mixexs: mixexs, lockfile: lockfile]
    end

    setup %{cwd: cwd} do
      assert {_, 0} = System.cmd("mix", ["deps.get"], cd: Path.join(cwd, "my_proj"))
      :ok
    end

    setup :with_lsp

    test "successfully asks to refetch deps on start",
         %{client: client, mixexs: mixexs, lockfile: lockfile} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")

      for pid <- context.pids do
        stop_supervised!(pid)
      end

      Process.unlink(context.server.lsp)
      shutdown_client!(context.client)
      shutdown_server!(context.server)

      # write new mix.exs and lockfile to simulate having them out of sync with the `deps` folder
      File.write!(
        mixexs,
        proj_mix_exs("""
        [{:temple, "~> 0.12.0"}]
        """)
      )

      File.write!(lockfile, """
      %{
        "floki": {:hex, :floki, "0.35.4", "cc947b446024732c07274ac656600c5c4dc014caa1f8fb2dfff93d275b83890d", [:mix], [], "hexpm", "27fa185d3469bd8fc5947ef0f8d5c4e47f0af02eb6b070b63c868f69e3af0204"},
        "phoenix_html": {:hex, :phoenix_html, "3.3.3", "380b8fb45912b5638d2f1d925a3771b4516b9a78587249cabe394e0a5d579dc9", [:mix], [{:plug, "~> 1.5", [hex: :plug, repo: "hexpm", optional: true]}], "hexpm", "923ebe6fec6e2e3b3e569dfbdc6560de932cd54b000ada0208b5f45024bdd76c"},
        "temple": {:hex, :temple, "0.12.0", "b50b806e1f1805219f0cbffc9c747c14f138543977fa6c01e74756c3e0daaa25", [:mix], [{:floki, ">= 0.0.0", [hex: :floki, repo: "hexpm", optional: false]}, {:phoenix_html, "~> 3.2", [hex: :phoenix_html, repo: "hexpm", optional: false]}, {:typed_struct, "~> 0.3", [hex: :typed_struct, repo: "hexpm", optional: false]}], "hexpm", "0d006e850bf21f6684fa0ee52ceeb2f8516bb0213bd003f6d38c66880262f8a8"},
        "typed_struct": {:hex, :typed_struct, "0.3.0", "939789e3c1dca39d7170c87f729127469d1315dcf99fee8e152bb774b17e7ff7", [:mix], [], "hexpm", "c50bd5c3a61fe4e198a8504f939be3d3c85903b382bde4865579bc23111d1b6d"},
      }
      """)

      %{client: client} = context = Map.merge(context, Map.new(with_lsp(context)))
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_request(client, "window/showMessageRequest", fn params ->
        assert %{
                 "type" => 1,
                 "actions" => [
                   %{"title" => "yes"},
                   %{"title" => "no"}
                 ]
               } = params

        # respond with yes
        %{"title" => "yes"}
      end)

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] Running `mix deps.get` in directory" <> _,
        "type" => 3
      }

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] Restarting runtime" <> _,
        "type" => 3
      }

      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")
    end

    test "successfully asks to refetch deps on compile",
         %{client: client, mixexs: mixexs, lockfile: lockfile} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")

      did_open(client, mixexs, File.read!(mixexs))

      # write new mix.exs and lockfile to simulate having them out of sync with the `deps` folder
      new_text =
        proj_mix_exs("""
        [{:temple, "~> 0.12.0"}]
        """)

      File.write!(mixexs, new_text)

      File.write!(lockfile, """
      %{
        "floki": {:hex, :floki, "0.35.4", "cc947b446024732c07274ac656600c5c4dc014caa1f8fb2dfff93d275b83890d", [:mix], [], "hexpm", "27fa185d3469bd8fc5947ef0f8d5c4e47f0af02eb6b070b63c868f69e3af0204"},
        "phoenix_html": {:hex, :phoenix_html, "3.3.3", "380b8fb45912b5638d2f1d925a3771b4516b9a78587249cabe394e0a5d579dc9", [:mix], [{:plug, "~> 1.5", [hex: :plug, repo: "hexpm", optional: true]}], "hexpm", "923ebe6fec6e2e3b3e569dfbdc6560de932cd54b000ada0208b5f45024bdd76c"},
        "temple": {:hex, :temple, "0.12.0", "b50b806e1f1805219f0cbffc9c747c14f138543977fa6c01e74756c3e0daaa25", [:mix], [{:floki, ">= 0.0.0", [hex: :floki, repo: "hexpm", optional: false]}, {:phoenix_html, "~> 3.2", [hex: :phoenix_html, repo: "hexpm", optional: false]}, {:typed_struct, "~> 0.3", [hex: :typed_struct, repo: "hexpm", optional: false]}], "hexpm", "0d006e850bf21f6684fa0ee52ceeb2f8516bb0213bd003f6d38c66880262f8a8"},
        "typed_struct": {:hex, :typed_struct, "0.3.0", "939789e3c1dca39d7170c87f729127469d1315dcf99fee8e152bb774b17e7ff7", [:mix], [], "hexpm", "c50bd5c3a61fe4e198a8504f939be3d3c85903b382bde4865579bc23111d1b6d"},
      }
      """)

      notify client, %{
        method: "textDocument/didSave",
        jsonrpc: "2.0",
        params: %{
          text: new_text,
          textDocument: %{uri: uri(mixexs)}
        }
      }

      assert_request(client, "window/showMessageRequest", fn params ->
        assert %{
                 "type" => 1,
                 "actions" => [
                   %{"title" => "yes"},
                   %{"title" => "no"}
                 ]
               } = params

        # respond with yes
        %{"title" => "yes"}
      end)

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] Running `mix deps.get` in directory" <> _,
        "type" => 3
      }

      assert_notification "window/logMessage", %{
        "message" => "[NextLS] Restarting runtime" <> _,
        "type" => 3
      }

      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")
    end
  end

  describe "local deps" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))

      File.write!(
        Path.join(tmp_dir, "my_proj/mix.exs"),
        proj_mix_exs("""
        [{:bar, path: "../bar"}]
        """)
      )

      File.mkdir_p!(Path.join(tmp_dir, "bar/lib"))
      File.write!(Path.join(tmp_dir, "bar/mix.exs"), bar_mix_exs())

      File.mkdir_p!(Path.join(tmp_dir, "baz/lib"))
      File.write!(Path.join(tmp_dir, "baz/mix.exs"), baz_mix_exs())

      cwd = tmp_dir
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
  end

  defp proj_mix_exs(deps) do
    """
    defmodule MyProj.MixProject do
      use Mix.Project

      def project do
        [
          app: :my_proj,
          version: "0.1.0",
          elixir: "~> 1.10",
          deps: #{deps}
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
