defmodule NextLS.PipeTest do
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
    defmodule Foo do
      def to_list() do
        Enum.to_list(Map.new())
      end
    end
    """

    File.write!(foo_path, foo)

    bar_path = Path.join(cwd, "lib/bar.ex")

    bar = """
    defmodule Bar do
      def to_list() do
        Map.new() |> Enum.to_list()
      end
    end
    """

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

    # the test runs so fast that it actually runs the executeCommand request
    # before the notifications are processed
    # could potentially add test affordances so that the server will send the test
    # a message when the notification has finished processing
    Process.sleep(50)
    context
  end

  test "transforms nested function expressions to pipes", %{client: client, foo_path: foo} do
    foo_uri = uri(foo)
    id = 1

    request client, %{
      method: "workspace/executeCommand",
      id: id,
      jsonrpc: "2.0",
      params: %{
        command: "to-pipe",
        arguments: [%{uri: foo_uri, position: %{line: 2, character: 19}}]
      }
    }

    assert_request(client, "workspace/applyEdit", 500, fn params ->
      assert %{"edit" => edit, "label" => "Extracted to a pipe"} = params

      assert %{
               "changes" => %{
                 ^foo_uri => [%{"newText" => text, "range" => range}]
               }
             } = edit

      expected = "Map.new() |> Enum.to_list()"
      assert text == expected
      assert range["start"] == %{"character" => 4, "line" => 2}
      assert range["end"] == %{"character" => 27, "line" => 2}
    end)
  end

  test "transforms pipes to function expressions", %{client: client, bar_path: bar} do
    bar_uri = uri(bar)
    id = 2

    request client, %{
      method: "workspace/executeCommand",
      id: id,
      jsonrpc: "2.0",
      params: %{
        command: "from-pipe",
        arguments: [%{uri: bar_uri, position: %{line: 2, character: 9}}]
      }
    }

    assert_request(client, "workspace/applyEdit", 500, fn params ->
      assert %{"edit" => edit, "label" => "Inlined pipe"} = params

      assert %{
               "changes" => %{
                 ^bar_uri => [%{"newText" => text, "range" => range}]
               }
             } = edit

      expected = "Enum.to_list(Map.new())"
      assert text == expected
      assert range["start"] == %{"character" => 4, "line" => 2}
      assert range["end"] == %{"character" => 31, "line" => 2}
    end)
  end
end
