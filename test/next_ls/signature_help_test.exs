defmodule NextLS.SignatureHelpTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir

  describe "function" do
    @describetag root_paths: ["my_proj"]
    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
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
      end
      """)

      imported = Path.join(cwd, "my_proj/lib/imported.ex")

      File.write!(imported, """
      defmodule Imported do
        def boom(boom1, _boom2) do
          boom1
        end
      end
      """)

      bar = Path.join(cwd, "my_proj/lib/bar.ex")

      File.write!(bar, """
      defmodule Bar do
        def run() do
          Remote.bang!()
        end
      end
      """)

      [bar: bar, imported: imported, remote: remote]
    end

    setup :with_lsp

    test "get signature help", %{client: client, bar: bar} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_is_ready(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 3, character: 16},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "activeParameter" => 0,
        "activeSignature" => 0,
        "signatures" => [
          %{
            "activeParameter" => 0,
            "parameters" => [
              %{"label" => "bang"}
            ],
            "documentation" => "need help",
            "label" => "bang!"
          }
        ]
      }
    end

    test "get signature help 2", %{client: client, bar: bar} = context do
      assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

      assert_is_ready(context, "my_proj")
      assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

      uri = uri(bar)

      request(client, %{
        method: "textDocument/signatureHelp",
        id: 4,
        jsonrpc: "2.0",
        params: %{
          position: %{line: 8, character: 10},
          textDocument: %{uri: uri}
        }
      })

      assert_result 4, %{
        "activeParameter" => 0,
        "activeSignature" => 0,
        "signatures" => [
          %{
            "activeParameter" => 0,
            "parameters" => [
              %{"label" => "bang"}
            ],
            "documentation" => "need help",
            "label" => "bang!"
          }
        ]
      }
    end
  end
end
