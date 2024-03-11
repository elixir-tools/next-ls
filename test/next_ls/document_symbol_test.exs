defmodule NextLS.DocumentSymbolTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.DocumentSymbol
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range

  test "normal module" do
    code = """
    defmodule Foo do
      defstruct [:foo, bar: "yo"]

      defmodule State do
        defstruct [:yo]

        def new(attrs) do
          struct(%__MODULE__{}, attrs)
        end
      end

      @spec run(any(), any(), any()) :: :something
      def run(foo, bar, baz) do
        :something
      end
    end
    """

    result = NextLS.DocumentSymbol.fetch(code)

    assert [
             %DocumentSymbol{
               children: [
                 %DocumentSymbol{
                   children: [
                     %DocumentSymbol{
                       children: [],
                       selection_range: %Range{
                         end: %Position{character: 13, line: 1},
                         start: %Position{character: 13, line: 1}
                       },
                       range: %Range{
                         end: %Position{character: 17, line: 1},
                         start: %Position{character: 13, line: 1}
                       },
                       kind: 8,
                       name: ":foo"
                     },
                     %DocumentSymbol{
                       children: [],
                       selection_range: %Range{
                         end: %Position{character: 19, line: 1},
                         start: %Position{character: 19, line: 1}
                       },
                       range: %Range{
                         end: %Position{character: 28, line: 1},
                         start: %Position{character: 19, line: 1}
                       },
                       kind: 8,
                       name: "bar: \"yo\""
                     }
                   ],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 1},
                     start: %Position{character: 2, line: 1}
                   },
                   range: %Range{
                     end: %Position{character: 29, line: 1},
                     start: %Position{character: 2, line: 1}
                   },
                   kind: 23,
                   name: "%Foo{}"
                 },
                 %DocumentSymbol{
                   children: [
                     %DocumentSymbol{
                       children: [
                         %DocumentSymbol{
                           children: [],
                           selection_range: %Range{
                             end: %Position{character: 15, line: 4},
                             start: %Position{character: 15, line: 4}
                           },
                           range: %Range{
                             end: %Position{character: 18, line: 4},
                             start: %Position{character: 15, line: 4}
                           },
                           kind: 8,
                           name: ":yo"
                         }
                       ],
                       selection_range: %Range{
                         end: %Position{character: 4, line: 4},
                         start: %Position{character: 4, line: 4}
                       },
                       range: %Range{
                         end: %Position{character: 19, line: 4},
                         start: %Position{character: 4, line: 4}
                       },
                       kind: 23,
                       name: "%State{}"
                     },
                     %DocumentSymbol{
                       children: [],
                       selection_range: %Range{
                         end: %Position{character: 4, line: 6},
                         start: %Position{character: 4, line: 6}
                       },
                       range: %Range{
                         end: %Position{character: 4, line: 8},
                         start: %Position{character: 4, line: 6}
                       },
                       kind: 12,
                       name: "def new(attrs)"
                     }
                   ],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 3},
                     start: %Position{character: 2, line: 3}
                   },
                   range: %Range{
                     end: %Position{character: 2, line: 9},
                     start: %Position{character: 2, line: 3}
                   },
                   kind: 2,
                   name: "State"
                 },
                 %DocumentSymbol{
                   children: [],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 11},
                     start: %Position{character: 2, line: 11}
                   },
                   range: %Range{
                     end: %Position{character: 46, line: 11},
                     start: %Position{character: 2, line: 11}
                   },
                   kind: 7,
                   name: "@spec run(any(), any(), any()) :: :something"
                 },
                 %DocumentSymbol{
                   children: [],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 12},
                     start: %Position{character: 2, line: 12}
                   },
                   range: %Range{
                     end: %Position{character: 2, line: 14},
                     start: %Position{character: 2, line: 12}
                   },
                   kind: 12,
                   name: "def run(foo, bar, baz)"
                 }
               ],
               selection_range: %Range{
                 end: %Position{character: 0, line: 0},
                 start: %Position{character: 0, line: 0}
               },
               range: %Range{
                 end: %Position{character: 0, line: 15},
                 start: %Position{character: 0, line: 0}
               },
               kind: 2,
               name: "Foo"
             }
           ] = result
  end

  test "test module" do
    code = """
    defmodule FooTest do
      describe "foo" do
        test "a thing", %{foo: foo} do
          assert true
        end

        feature "does a browser thing", %{session: session} do
          assert true
        end
      end

      property "the property holds" do
        assert true
      end

      test "a thing", %{foo: foo} do
        assert true
      end
    end
    """

    result = NextLS.DocumentSymbol.fetch(code)

    assert [
             %GenLSP.Structures.DocumentSymbol{
               children: [
                 %DocumentSymbol{
                   children: [
                     %DocumentSymbol{
                       children: [],
                       selection_range: %Range{
                         end: %Position{character: 4, line: 2},
                         start: %Position{character: 4, line: 2}
                       },
                       range: %Range{
                         end: %Position{character: 4, line: 4},
                         start: %Position{character: 4, line: 2}
                       },
                       deprecated: nil,
                       tags: nil,
                       kind: 9,
                       detail: nil,
                       name: "test \"a thing\""
                     },
                     %DocumentSymbol{
                       children: [],
                       selection_range: %Range{
                         end: %Position{character: 4, line: 6},
                         start: %Position{character: 4, line: 6}
                       },
                       range: %Range{
                         end: %Position{character: 4, line: 8},
                         start: %Position{character: 4, line: 6}
                       },
                       deprecated: nil,
                       tags: nil,
                       kind: 9,
                       detail: nil,
                       name: "feature \"does a browser thing\""
                     }
                   ],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 1},
                     start: %Position{character: 2, line: 1}
                   },
                   range: %Range{
                     end: %Position{character: 2, line: 9},
                     start: %Position{character: 2, line: 1}
                   },
                   deprecated: nil,
                   tags: nil,
                   kind: 5,
                   detail: nil,
                   name: "describe \"foo\""
                 },
                 %DocumentSymbol{
                   children: [],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 11},
                     start: %Position{character: 2, line: 11}
                   },
                   range: %Range{
                     end: %Position{character: 2, line: 13},
                     start: %Position{character: 2, line: 11}
                   },
                   deprecated: nil,
                   tags: nil,
                   kind: 9,
                   detail: nil,
                   name: "property \"the property holds\""
                 },
                 %DocumentSymbol{
                   children: [],
                   selection_range: %Range{
                     end: %Position{character: 2, line: 15},
                     start: %Position{character: 2, line: 15}
                   },
                   range: %Range{
                     end: %Position{character: 2, line: 17},
                     start: %Position{character: 2, line: 15}
                   },
                   deprecated: nil,
                   tags: nil,
                   kind: 9,
                   detail: nil,
                   name: "test \"a thing\""
                 }
               ],
               selection_range: %Range{
                 end: %Position{character: 0, line: 0},
                 start: %Position{character: 0, line: 0}
               },
               range: %Range{
                 end: %Position{character: 0, line: 18},
                 start: %Position{character: 0, line: 0}
               },
               deprecated: nil,
               tags: nil,
               kind: 2,
               detail: nil,
               name: "FooTest"
             }
           ] == result
  end

  test "two modules in one file" do
    code = """
    defmodule Foo do
      def run, do: :ok
    end

    defmodule Bar do
      def run, do: :ok
    end
    """

    result = NextLS.DocumentSymbol.fetch(code)

    assert [
             %GenLSP.Structures.DocumentSymbol{
               children: [
                 %GenLSP.Structures.DocumentSymbol{
                   children: [],
                   selection_range: %GenLSP.Structures.Range{
                     end: %GenLSP.Structures.Position{character: 2, line: 1},
                     start: %GenLSP.Structures.Position{character: 2, line: 1}
                   },
                   range: %GenLSP.Structures.Range{
                     end: %GenLSP.Structures.Position{character: 18, line: 1},
                     start: %GenLSP.Structures.Position{character: 2, line: 1}
                   },
                   deprecated: nil,
                   tags: nil,
                   kind: 12,
                   detail: nil,
                   name: "def run"
                 }
               ],
               selection_range: %GenLSP.Structures.Range{
                 end: %GenLSP.Structures.Position{character: 0, line: 0},
                 start: %GenLSP.Structures.Position{character: 0, line: 0}
               },
               range: %GenLSP.Structures.Range{
                 end: %GenLSP.Structures.Position{character: 0, line: 2},
                 start: %GenLSP.Structures.Position{character: 0, line: 0}
               },
               deprecated: nil,
               tags: nil,
               kind: 2,
               detail: nil,
               name: "Foo"
             },
             %GenLSP.Structures.DocumentSymbol{
               children: [
                 %GenLSP.Structures.DocumentSymbol{
                   children: [],
                   selection_range: %GenLSP.Structures.Range{
                     end: %GenLSP.Structures.Position{character: 2, line: 5},
                     start: %GenLSP.Structures.Position{character: 2, line: 5}
                   },
                   range: %GenLSP.Structures.Range{
                     end: %GenLSP.Structures.Position{character: 18, line: 5},
                     start: %GenLSP.Structures.Position{character: 2, line: 5}
                   },
                   deprecated: nil,
                   tags: nil,
                   kind: 12,
                   detail: nil,
                   name: "def run"
                 }
               ],
               selection_range: %GenLSP.Structures.Range{
                 end: %GenLSP.Structures.Position{character: 0, line: 4},
                 start: %GenLSP.Structures.Position{character: 0, line: 4}
               },
               range: %GenLSP.Structures.Range{
                 end: %GenLSP.Structures.Position{character: 0, line: 6},
                 start: %GenLSP.Structures.Position{character: 0, line: 4}
               },
               deprecated: nil,
               tags: nil,
               kind: 2,
               detail: nil,
               name: "Bar"
             }
           ] == result
  end
end
