defmodule NextLS.ReferencesTest do
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]
  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), mix_exs())

    [cwd: tmp_dir]
  end

  setup %{cwd: cwd} do
    peace = Path.join(cwd, "my_proj/lib/peace.ex")

    File.write!(peace, """
    defmodule MyApp.Peace do
      def and_love() do
        "✌️"
      end
    end
    """)

    bar = Path.join(cwd, "my_proj/lib/bar.ex")

    File.write!(bar, """
    defmodule Bar do
      alias MyApp.Peace
      def run() do
        Peace.and_love()
      end
    end
    """)

    [bar: bar, peace: peace]
  end

  setup :with_lsp

  test "list function references", %{client: client, bar: bar, peace: peace} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_request(client, "client/registerCapability", fn _params -> nil end)
    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    request(client, %{
      method: "textDocument/references",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 1, character: 6},
        textDocument: %{uri: uri(peace)},
        context: %{includeDeclaration: true}
      }
    })

    uri = uri(bar)

    assert_result2(
      4,
      [
        %{
          "uri" => uri,
          "range" => %{
            "start" => %{"line" => 3, "character" => 10},
            "end" => %{"line" => 3, "character" => 18}
          }
        }
      ]
    )
  end

  test "list module references", %{client: client, bar: bar, peace: peace} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_request(client, "client/registerCapability", fn _params -> nil end)
    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    request(client, %{
      method: "textDocument/references",
      id: 4,
      jsonrpc: "2.0",
      params: %{
        position: %{line: 0, character: 10},
        textDocument: %{uri: uri(peace)},
        context: %{includeDeclaration: true}
      }
    })

    uri = uri(bar)

    assert_result 4,
                  [
                    %{
                      "uri" => ^uri,
                      "range" => %{
                        "start" => %{"line" => 3, "character" => 4},
                        "end" => %{"line" => 3, "character" => 9}
                      }
                    }
                  ]
  end
end
