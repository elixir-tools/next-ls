defmodule NextLS.ElixirExtensionTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.Position
  alias NextLS.DiagnosticCache
  alias NextLS.ElixirExtension

  setup do
    cache = start_supervised!(DiagnosticCache)
    start_supervised!({Registry, [keys: :unique, name: Registry.ElixirExtensionTest]})

    extension =
      start_supervised!({ElixirExtension, cache: cache, registry: Registry.ElixirExtensionTest, publisher: self()})

    Process.link(extension)

    [extension: extension, cache: cache]
  end

  test "inserts lsp diagnostics into cache", %{extension: extension, cache: cache} do
    only_line = %Mix.Task.Compiler.Diagnostic{
      file: "lib/bar.ex",
      severity: :warning,
      message: "kind of bad",
      position: 2,
      compiler_name: "Elixir",
      details: nil
    }

    line_and_col = %Mix.Task.Compiler.Diagnostic{
      file: "lib/foo.ex",
      severity: :error,
      message: "nothing works",
      position: {4, 7},
      compiler_name: "Elixir",
      details: nil
    }

    with_iodata = %Mix.Task.Compiler.Diagnostic{
      file: "/Users/mitchell/src/next_ls/lib/next_ls/runtime.ex",
      severity: :warning,
      message: [
        "ElixirExtension.foo/0",
        " is undefined (module ",
        "ElixirExtension",
        " is not available or is yet to be defined)"
      ],
      position: 29,
      compiler_name: "Elixir",
      details: nil
    }

    start_and_end = %Mix.Task.Compiler.Diagnostic{
      file: "lib/baz.ex",
      severity: :hint,
      message: "here's a hint",
      position: {4, 7, 8, 3},
      compiler_name: "Elixir",
      details: nil
    }

    send(extension, {:compiler, [only_line, line_and_col, start_and_end, with_iodata]})

    assert_receive :publish

    assert %{
             with_iodata.file => [
               %GenLSP.Structures.Diagnostic{
                 data: %{"namespace" => "elixir"},
                 severity: 2,
                 message:
                   "ElixirExtension.foo/0" <>
                     " is undefined (module " <> "ElixirExtension" <> " is not available or is yet to be defined)",
                 source: "Elixir",
                 range: %GenLSP.Structures.Range{
                   start: %Position{
                     line: 28,
                     character: 0
                   },
                   end: %Position{
                     line: 28,
                     character: 999
                   }
                 }
               }
             ],
             only_line.file => [
               %GenLSP.Structures.Diagnostic{
                 data: %{"namespace" => "elixir"},
                 severity: 2,
                 message: "kind of bad",
                 source: "Elixir",
                 range: %GenLSP.Structures.Range{
                   start: %Position{
                     line: 1,
                     character: 0
                   },
                   end: %Position{
                     line: 1,
                     character: 999
                   }
                 }
               }
             ],
             line_and_col.file => [
               %GenLSP.Structures.Diagnostic{
                 data: %{"namespace" => "elixir"},
                 severity: 1,
                 message: "nothing works",
                 source: "Elixir",
                 range: %GenLSP.Structures.Range{
                   start: %Position{
                     line: 3,
                     character: 6
                   },
                   end: %Position{
                     line: 3,
                     character: 999
                   }
                 }
               }
             ],
             start_and_end.file => [
               %GenLSP.Structures.Diagnostic{
                 data: %{"namespace" => "elixir"},
                 severity: 4,
                 message: "here's a hint",
                 source: "Elixir",
                 range: %GenLSP.Structures.Range{
                   start: %Position{
                     line: 3,
                     character: 6
                   },
                   end: %Position{
                     line: 7,
                     character: 2
                   }
                 }
               }
             ]
           } == DiagnosticCache.get(cache).elixir
  end
end
