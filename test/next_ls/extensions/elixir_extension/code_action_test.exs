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

    foo = """
    defmodule MyProj.Foo do
      def hello() do
        foo = :bar
        :world
      end
    end
    """

    File.write!(foo_path, foo)

    [foo: foo, foo_path: foo_path]
  end

  setup :with_lsp

  setup context do
    assert :ok == notify(context.client, %{method: "initialized", jsonrpc: "2.0", params: %{}})
    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    did_open(context.client, context.foo_path, context.foo)
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
              "range" => %{"end" => %{"character" => 999, "line" => 2}, "start" => %{"character" => 4, "line" => 2}},
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
end
