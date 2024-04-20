defmodule NextLS.CredoExtensionTest do
  # this test installs and compiles credo from scratch everytime it runs
  # we need to determine a way to cache this without losing the utility of
  # the test.
  use ExUnit.Case, async: true

  import GenLSP.Test
  import NextLS.Support.Utils

  @moduletag :tmp_dir
  @moduletag root_paths: ["my_proj"]

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    File.write!(Path.join(tmp_dir, "my_proj/mix.exs"), proj_mix_exs())

    [cwd: tmp_dir]
  end

  setup %{cwd: cwd} do
    foo = Path.join(cwd, "my_proj/lib/foo.ex")

    File.write!(foo, """
    defmodule Foo do
      def run() do
        dbg(:ok)
      end
    end
    """)

    credo = Path.join(cwd, "my_proj/.credo.exs")

    File.write!(credo, ~S"""
    %{
      configs: [
        %{
          name: "default",
          files: %{
            included: ["lib/", "test/"],
            excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
          },
          plugins: [],
          requires: [],
          strict: false,
          parse_timeout: 5000,
          color: true,
          checks: %{
            enabled: [
              {Credo.Check.Readability.ModuleDoc, []},
              {Credo.Check.Warning.Dbg, []},
              {Credo.Check.Warning.IoInspect, []},
            ],
            disabled: []
          }
        }
      ]
    }
    """)

    [foo: foo]
  end

  setup %{cwd: cwd} do
    assert {_, 0} = System.cmd("mix", ["deps.get"], cd: Path.join(cwd, "my_proj"))
    :ok
  end

  setup :with_lsp

  @tag init_options: %{"extensions" => %{"credo" => %{"enable" => false}}}
  test "disables Credo", %{client: client} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")

    assert_notification "window/logMessage", %{
      "message" => "[Next LS] [extension] Credo disabled",
      "type" => 3
    }
  end

  @tag init_options: %{"extensions" => %{"credo" => %{"cli_options" => ["--only", "warning"]}}}
  test "configures cli options", %{client: client, foo: foo} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")

    assert_notification "window/logMessage", %{
      "message" => "[Next LS] [extension] Credo initializing with options" <> _,
      "type" => 3
    }

    uri = uri(foo)

    assert_notification "textDocument/publishDiagnostics", %{
      "uri" => ^uri,
      "diagnostics" => [
        %{
          "code" => "Credo.Check.Warning.Dbg",
          "codeDescription" => %{
            "href" => "https://hexdocs.pm/credo/Credo.Check.Warning.Dbg.html"
          },
          "data" => %{
            "check" => "Elixir.Credo.Check.Warning.Dbg",
            "file" => "lib/foo.ex"
          },
          "message" => "There should be no calls to `dbg/1`.",
          "range" => %{
            "end" => %{"character" => 7, "line" => 2},
            "start" => %{"character" => 4, "line" => 2}
          },
          "severity" => 2,
          "source" => "credo"
        }
      ]
    }
  end

  test "publishes credo diagnostics", %{client: client, foo: foo} = context do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_is_ready(context, "my_proj")
    assert_compiled(context, "my_proj")
    assert_notification "$/progress", %{"value" => %{"kind" => "end", "message" => "Finished indexing!"}}

    assert_notification "window/logMessage", %{
      "message" => "[Next LS] [extension] Credo initializing with options" <> _,
      "type" => 3
    }

    uri = uri(foo)

    assert_notification "textDocument/publishDiagnostics", %{
      "uri" => ^uri,
      "diagnostics" => [
        %{
          "code" => "Credo.Check.Warning.Dbg",
          "codeDescription" => %{
            "href" => "https://hexdocs.pm/credo/Credo.Check.Warning.Dbg.html"
          },
          "data" => %{
            "check" => "Elixir.Credo.Check.Warning.Dbg",
            "file" => "lib/foo.ex"
          },
          "message" => "There should be no calls to `dbg/1`.",
          "range" => %{
            "end" => %{"character" => 7, "line" => 2},
            "start" => %{"character" => 4, "line" => 2}
          },
          "severity" => 2,
          "source" => "credo"
        },
        %{
          "code" => "Credo.Check.Readability.ModuleDoc",
          "codeDescription" => %{
            "href" => "https://hexdocs.pm/credo/Credo.Check.Readability.ModuleDoc.html"
          },
          "data" => %{
            "check" => "Elixir.Credo.Check.Readability.ModuleDoc",
            "file" => "lib/foo.ex"
          },
          "message" => "Modules should have a @moduledoc tag.",
          "range" => %{
            "end" => %{"character" => 13, "line" => 0},
            "start" => %{"character" => 10, "line" => 0}
          },
          "severity" => 3,
          "source" => "credo"
        }
      ]
    }
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
            {:credo, "~> 1.7"},
            {:jason, github: "mhanberg/jason", branch: "format", override: true}
          ]
        ]
      end
    end
    """
  end
end
