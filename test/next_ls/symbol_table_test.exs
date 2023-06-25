defmodule NextLS.SymbolTableTest do
  use ExUnit.Case, async: true
  @moduletag :tmp_dir

  alias NextLS.SymbolTable

  setup %{tmp_dir: dir} do
    pid = start_supervised!({SymbolTable, [path: dir]})

    Process.link(pid)
    [pid: pid, dir: dir]
  end

  test "creates a dets table", %{dir: dir, pid: pid} do
    assert File.exists?(Path.join([dir, "symbol_table.dets"]))
    assert :sys.get_state(pid).table == :symbol_table
  end

  test "builds the symbol table", %{pid: pid} do
    symbols = symbols()

    SymbolTable.put_symbols(pid, symbols)

    assert [
             %SymbolTable.Symbol{
               module: "NextLS",
               file: "/Users/alice/next_ls/lib/next_ls.ex",
               type: :def,
               name: :start_link,
               line: 45,
               col: nil
             },
             %SymbolTable.Symbol{
               module: "NextLS",
               file: "/Users/alice/next_ls/lib/next_ls.ex",
               type: :def,
               name: :start_link,
               line: 44,
               col: nil
             }
           ] == SymbolTable.symbols(pid)
  end

  defp symbols() do
    %{
      file: "/Users/alice/next_ls/lib/next_ls.ex",
      module: "NextLS",
      defs: [
        start_link:
          {:v1, :def, [line: 44],
           [
             {[line: 44], [{:args, [version: 0, line: 44, column: 18], nil}], [],
              {:__block__, [],
               [
                 {:=,
                  [
                    end_of_expression: [newlines: 2, line: 52, column: 9],
                    line: 45,
                    column: 18
                  ],
                  [
                    {{:args, [version: 1, line: 45, column: 6], nil}, {:opts, [version: 2, line: 45, column: 12], nil}},
                    {{:., [line: 46, column: 14], [Keyword, :split]},
                     [closing: [line: 52, column: 8], line: 46, column: 15],
                     [
                       {:args, [version: 0, line: 46, column: 21], nil},
                       [:cache, :task_supervisor, :dynamic_supervisor, :extensions, :extension_registry]
                     ]}
                  ]},
                 {{:., [line: 54, column: 11], [GenLSP, :start_link]},
                  [closing: [line: 54, column: 45], line: 54, column: 12],
                  [
                    NextLS,
                    {:args, [version: 1, line: 54, column: 35], nil},
                    {:opts, [version: 2, line: 54, column: 41], nil}
                  ]}
               ]}},
             {[line: 45], [{:args, [version: 0, line: 45, column: 18], nil}], [],
              {:__block__, [],
               [
                 {:=,
                  [
                    end_of_expression: [newlines: 2, line: 52, column: 9],
                    line: 45,
                    column: 18
                  ],
                  [
                    {{:args, [version: 1, line: 45, column: 6], nil}, {:opts, [version: 2, line: 45, column: 12], nil}},
                    {{:., [line: 46, column: 14], [Keyword, :split]},
                     [closing: [line: 52, column: 8], line: 46, column: 15],
                     [
                       {:args, [version: 0, line: 46, column: 21], nil},
                       [:cache, :task_supervisor, :dynamic_supervisor, :extensions, :extension_registry]
                     ]}
                  ]},
                 {{:., [line: 54, column: 11], [GenLSP, :start_link]},
                  [closing: [line: 54, column: 45], line: 54, column: 12],
                  [
                    NextLS,
                    {:args, [version: 1, line: 54, column: 35], nil},
                    {:opts, [version: 2, line: 54, column: 41], nil}
                  ]}
               ]}}
           ]}
      ]
    }
  end
end
