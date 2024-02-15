defmodule NextLS.DiagnosticsTest do
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

  setup %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "my_proj/lib/bar.ex"), """
    defmodule Bar do
      defstruct [:foo]

      def foo(arg1) do
      end
    end
    """)

    File.write!(Path.join(tmp_dir, "my_proj/lib/code_action.ex"), """
    defmodule Foo.CodeAction do
      # some comment

      defmodule NestedMod do
        def foo do
          :ok
        end
      end
    end
    """)

    File.write!(Path.join(tmp_dir, "my_proj/lib/foo.ex"), """
    defmodule Foo do
    end
    """)

    File.write!(Path.join(tmp_dir, "my_proj/lib/project.ex"), """
    defmodule Project do
      def hello do
        :world
      end
    end
    """)

    File.rm_rf!(Path.join(tmp_dir, ".elixir-tools"))

    :ok
  end

  setup :with_lsp

  test "publishes diagnostics once the client has initialized", %{client: client, cwd: cwd} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_notification "window/logMessage", %{
      "message" => "[NextLS] NextLS v" <> _,
      "type" => 4
    }

    title = "Initializing NextLS runtime for folder #{context.module}-my_proj..."

    assert_notification "$/progress", %{
      "value" => %{"kind" => "begin", "title" => ^title}
    }

    message = "NextLS runtime for folder #{context.module}-my_proj has initialized!"

    assert_notification "$/progress", %{
      "value" => %{
        "kind" => "end",
        "message" => ^message
      }
    }

    assert_compiled(context, "my_proj")

    for file <- ["bar.ex"] do
      uri =
        to_string(%URI{
          host: "",
          scheme: "file",
          path: Path.join([cwd, "my_proj/lib", file])
        })

      char = if Version.match?(System.version(), ">= 1.15.0"), do: 10, else: 0

      assert_notification "textDocument/publishDiagnostics", %{
        "uri" => ^uri,
        "diagnostics" => [
          %{
            "source" => "Elixir",
            "severity" => 2,
            "message" =>
              "variable \"arg1\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
            "range" => %{
              "start" => %{"line" => 3, "character" => ^char},
              "end" => %{"line" => 3, "character" => 14}
            }
          }
        ]
      }
    end
  end
end
