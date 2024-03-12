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

      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Bar do
        alias Remote.NestedAlias

        def run() do
          Remote.bang!("bang")

          Remote.bangs!("bang1", "bang2")

          Remote.bangs!(
            "bang1",
            "bang2"
          )

         NestedAlias.bang!("bang")
        end
      end
      """)

      baz = Path.join(cwd, "my_proj/lib/baz.ex")

      File.write!(baz, """
      defmodule Baz do
        import Imported

        def run() do
          boom([1, 2], 1)

          get_in(%{boom: %{bar: 1}}, [:boom, :bar])
        end
      end
      """)

      [bar: bar, imported: imported, remote: remote, baz: baz, nested_alias: nested_alias]
    end

    setup :with_lsp

    setup context do
      assert :ok == notify(context.client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
      assert_is_ready(context, "my_proj")
      assert_compiled(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}
    end

    test "get signature help", %{client: client, bar: bar} do
      uri = uri(bar)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 4, character: 19},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "signatures" => [
          %{
            "parameters" => [
              %{"label" => "bang"}
            ],
            "label" => "bang!(bang)"
          }
        ]
      }
    end

    test "get signature help with multiple params", %{client: client, bar: bar} do
      uri = uri(bar)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 6, character: 13},
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
            "label" => "bangs!(bang1, bang2)"
          }
        ]
      }
    end

    test "get signature help with parameters on multiple lines", %{client: client, bar: bar} do
      uri = uri(bar)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 9, character: 13},
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
            "label" => "bangs!(bang1, bang2)"
          }
        ]
      }
    end

    # test "get signature help with aliased module", %{client: client, bar: bar} do
    #   uri = uri(bar)

    #   request(client, %{
    #     method: "textDocument/signatureHelp",
    #     id: 4,
    #     jsonrpc: "2.0",
    #     params: %{
    #       position: %{line: 12, character: 13},
    #       textDocument: %{uri: uri}
    #     }
    #   })

    #   assert_result 4, %{
    #     "signatures" => [
    #       %{
    #         "parameters" => [
    #           %{"label" => "bang"}
    #         ],
    #         "label" => "bang!(bang)"
    #       }
    #     ]
    #   }
    # end

    #   test "get signature from imported functions", %{client: client, baz: baz} do
    #     uri = uri(baz)

    #     request(client, %{
    #       method: "textDocument/signatureHelp",
    #       id: 4,
    #       jsonrpc: "2.0",
    #       params: %{
    #         position: %{line: 4, character: 13},
    #         textDocument: %{uri: uri}
    #       }
    #     })

    #     assert_result 4, %{
    #       "signatures" => [
    #         %{
    #           "parameters" => [
    #             %{"label" => "boom1"},
    #             %{"label" => "boom2"}
    #           ],
    #           "label" => "boom(boom1, boom2)"
    #         }
    #       ]
    #     }
    #   end

    #   test "get signature for kernel functions", %{client: client, baz: baz} do
    #     uri = uri(baz)

    #     request(client, %{
    #       method: "textDocument/signatureHelp",
    #       id: 4,
    #       jsonrpc: "2.0",
    #       params: %{
    #         position: %{line: 9, character: 13},
    #         textDocument: %{uri: uri}
    #       }
    #     })

    #     assert_result 4, %{
    #       "signatures" => [
    #         %{
    #           "parameters" => [
    #             %{"label" => "boom1"},
    #             %{"label" => "boom2"}
    #           ],
    #           "label" => "get_in(boom1, boom2)"
    #         }
    #       ]
    #     }
    #   end
  end
end
