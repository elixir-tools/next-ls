defmodule NextLS.SignatureHelpTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir

  describe "function" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib/remote"))
      File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())
      [cwd: tmp_dir]
    end

    setup %{cwd: cwd} do
      remote = Path.join(cwd, "my_proj/lib/remote.ex")

      File.write!(remote, """
      defmodule Remote do
        @doc "doc example"
        def bang!(bang) do
          bang
        end

        def bangs!(bang1, _bang2) do
          bang1
        end
      end
      """)

      nested_alias = Path.join(cwd, "my_proj/lib/remote/nested_alias.ex")

      File.write!(nested_alias, """
      defmodule Remote.NestedAlias do
        def bang!(bang) do
          bang
        end
      end
      """)

      imported = Path.join(cwd, "my_proj/lib/imported.ex")

      File.write!(imported, """
      defmodule Imported do
        def boom([] = boom1, _boom2) do
          boom1
        end
      end
      """)

      [imported: imported, remote: remote, nested_alias: nested_alias]
    end

    setup :with_lsp

    setup context do
      assert :ok == notify(context.client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}
    end

    test "get signature help", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          Remote.bang!("bang1")
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 2, character: 15},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang"}
            ],
            "label" => "bang!(bang)",
            "documentation" => %{
              "kind" => "markdown",
              "value" => "doc example"
            },
            "activeParameter" => 0
          }
        ]
      }
    end

    test "get signature help with multiple params", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          Remote.bangs!("bang1", "bang2")
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 2, character: 15},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang1"},
              %{"label" => "bang2"}
            ],
            "label" => "bangs!(bang1, bang2)",
            "activeParameter" => 0
          }
        ]
      }
    end

    test "get signature help with multiple params and active parameter 1", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          Remote.bangs!("bang1", "bang2")
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 2, character: 22},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang1"},
              %{"label" => "bang2"}
            ],
            "label" => "bangs!(bang1, bang2)",
            "activeParameter" => 1
          }
        ]
      }
    end

    test "get signature help with parameters on multiple lines", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          Remote.bangs!(
            "bang1",
            "bang2"
          )
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 4, character: 6},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang1"},
              %{"label" => "bang2"}
            ],
            "label" => "bangs!(bang1, bang2)",
            "activeParameter" => 1
          }
        ]
      }
    end

    test "get signature help with pipe", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          "bang1" |> Remote.bangs!("bang2")
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 2, character: 25},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang1"},
              %{"label" => "bang2"}
            ],
            "label" => "bangs!(bang1, bang2)",
            "activeParameter" => 1
          }
        ]
      }
    end

    test "get signature help with multiple pipe", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          ["bang", "bang"]
          |> Enum.map(fn name -> "super" <> name end)
          |> Remote.bangs!()
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 3, character: 25},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "enumerable"},
              %{"label" => "fun"}
            ],
            "label" => "map(enumerable, fun)",
            "activeParameter" => 1
          }
        ]
      }
    end

    test "get signature help with param function on multiple lines", %{client: client, cwd: cwd} do
      did_open(client, Path.join(cwd, "my_proj/lib/bar.ex"), """
      defmodule Bar do
        def run do
          Enum.map([1, 2, 3], fn n ->
            n + 1
          end)
        end
      end
      """)

      uri = "file://#{cwd}/my_proj/lib/bar.ex"

      did_change(client, uri)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 3, character: 3},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "enumerable"},
              %{"label" => "fun"}
            ],
            "label" => "map(enumerable, fun)",
            "activeParameter" => 1
          }
        ]
      }
    end
  end
end
