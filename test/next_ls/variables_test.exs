defmodule NextLS.VariablesTest do
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
    defmodule MyApp do
      def to_list(map) do
        map = %{foo: :bar}
        Enum.to_list(map)
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

  test "extracts variables to module attributes", %{client: client, foo_path: foo} do
    foo_uri = uri(foo)
    id = 1

    request client, %{
      method: "workspace/executeCommand",
      id: id,
      jsonrpc: "2.0",
      params: %{
        command: "extract-variable",
        arguments: [%{uri: foo_uri, position: %{line: 2, character: 8}}]
      }
    }

    expected_edit =
      String.trim("""
      defmodule MyApp do
        @map %{foo: :bar}
        def to_list(map) do
          Enum.to_list(@map)
        end
      end
      """)

    assert_request(client, "workspace/applyEdit", 500, fn params ->
      assert %{"edit" => edit, "label" => "Extracted variable to a module attribute"} = params

      assert %{
               "changes" => %{
                 ^foo_uri => [%{"newText" => text, "range" => range}]
               }
             } = edit

      assert text == expected_edit

      assert range["start"] == %{"character" => 0, "line" => 0}
      assert range["end"] == %{"character" => 3, "line" => 5}
    end)
  end
end
