defmodule NextLS.AutocompleteTest do
  use ExUnit.Case, async: true

  import NextLS.Support.Utils

  alias NextLS.Runtime

  require Runtime

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "mix.exs"), mix_exs())
    File.mkdir_p!(Path.join(tmp_dir, "lib"))

    File.write!(Path.join(tmp_dir, "lib/bar.ex"), """
    defmodule Bar do
      defstruct [:foo]

      def foo(arg1) do
      end
    end
    """)

    File.write!(Path.join(tmp_dir, "lib/sublevel.ex"), """
    defmodule SublevelTest.LevelA.LevelB do
    end
    """)

    File.write!(Path.join(tmp_dir, "lib/my_struct.ex"), """
    defmodule Something.Foo.MyStruct do
      defstruct [:my_val]
    end
    """)

    File.write!(Path.join(tmp_dir, "lib/badmod.ex"), """
    defmodule(:"Elixir.NextLS.AutocompleteTest.Unicodé", do: nil)
    """)

    me = self()

    {:ok, logger} =
      Task.start_link(fn ->
        recv = fn recv ->
          receive do
            {:"$gen_cast", msg} -> send(me, msg)
          end

          recv.(recv)
        end

        recv.(recv)
      end)

    on_init = fn msg -> send(me, msg) end
    start_supervised!({Registry, keys: :duplicate, name: __MODULE__.Registry})
    tvisor = start_supervised!(Task.Supervisor)

    cwd = tmp_dir

    pid =
      start_supervised!(
        {Runtime,
         name: "my_proj",
         on_initialized: on_init,
         task_supervisor: tvisor,
         working_dir: cwd,
         uri: "file://#{cwd}",
         elixir_bin_path: "elixir" |> System.find_executable() |> Path.dirname(),
         parent: self(),
         lsp_pid: self(),
         logger: logger,
         db: :some_db,
         mix_env: "dev",
         mix_target: "host",
         mix_home: Path.join(cwd, ".mix"),
         registry: __MODULE__.Registry}
      )

    Process.link(pid)

    assert_receive :ready

    Runtime.compile(pid, caller_ref: make_ref())
    assert_receive {:compiler_result, _, _, {:ok, _}}

    [runtime: pid]
  end

  defp base_env do
    %{variables: [], aliases: [], functions: [{Kernel, [+: 1, +: 2, ++: 2, -: 1, -: 2, --: 2]}], macros: []}
  end

  defp expand(runtime, expr, env \\ base_env()) do
    NextLS.Autocomplete.expand(Enum.reverse(expr), runtime, env)
  end

  test "Erlang module completion", %{runtime: runtime} do
    assert expand(runtime, ~c":zl") == {:yes, [%{name: "zlib", data: :zlib, kind: :module}]}
  end

  test "Erlang module no completion", %{runtime: runtime} do
    assert expand(runtime, ~c":unknown") == {:no, []}
  end

  test "Erlang module multiple values completion", %{runtime: runtime} do
    {:yes, list} = expand(runtime, ~c":logger")

    assert Enum.any?(list, fn c ->
             match?(%{name: "logger", kind: :module}, c)
           end)

    assert Enum.any?(list, fn c ->
             match?(%{name: "logger_proxy", kind: :module}, c)
           end)
  end

  test "Erlang root completion", %{runtime: runtime} do
    {:yes, list} = expand(runtime, ~c":")
    assert is_list(list)
    assert Enum.any?(list, fn c -> match?(%{name: "lists", kind: :module}, c) end)
    refute Enum.any?(list, fn c -> match?(%{name: "Elixir.List", kind: :module}, c) end)
  end

  test "Elixir proxy", %{runtime: runtime} do
    {:yes, [elixir_entry | _list]} = expand(runtime, ~c"E")
    assert %{name: "Elixir", kind: :module} = elixir_entry
  end

  test "Elixir completion", %{runtime: runtime} do
    assert {:yes,
            [
              %{name: "Enum", kind: :module},
              %{name: "Enumerable", kind: :module}
            ]} = expand(runtime, ~c"En")

    assert {:yes, [%{name: "Enumerable", kind: :module}]} = expand(runtime, ~c"Enumera")
  end

  # test "Elixir type completion", %{runtime: runtime} do
  #   assert expand(runtime, ~c"t :gen_ser") == {:yes, ~c"ver", []}
  #   assert expand(runtime, ~c"t String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}

  #   assert expand(runtime, ~c"t String.") ==
  #            {:yes, ~c"", [~c"codepoint/0", ~c"grapheme/0", ~c"pattern/0", ~c"t/0"]}

  #   assert expand(runtime, ~c"t String.grap") == {:yes, ~c"heme", []}
  #   assert expand(runtime, ~c"t  String.grap") == {:yes, ~c"heme", []}
  #   assert {:yes, ~c"", [~c"date_time/0" | _]} = expand(runtime, ~c"t :file.")
  #   assert expand(runtime, ~c"t :file.n") == {:yes, ~c"ame", []}
  # end

  # test "Elixir callback completion", %{runtime: runtime} do
  #   assert expand(runtime, ~c"b :strin") == {:yes, ~c"g", []}
  #   assert expand(runtime, ~c"b String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}
  #   assert expand(runtime, ~c"b String.") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"b Access.") == {:yes, ~c"", [~c"fetch/2", ~c"get_and_update/3", ~c"pop/2"]}
  #   assert expand(runtime, ~c"b GenServer.term") == {:yes, ~c"inate", []}
  #   assert expand(runtime, ~c"b   GenServer.term") == {:yes, ~c"inate", []}
  #   assert expand(runtime, ~c"b :gen_server.handle_in") == {:yes, ~c"fo", []}
  # end

  # test "Elixir helper completion with parentheses", %{runtime: runtime} do
  #   assert expand(runtime, ~c"t(:gen_ser") == {:yes, ~c"ver", []}
  #   assert expand(runtime, ~c"t(String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}

  #   assert expand(runtime, ~c"t(String.") ==
  #            {:yes, ~c"", [~c"codepoint/0", ~c"grapheme/0", ~c"pattern/0", ~c"t/0"]}

  #   assert expand(runtime, ~c"t(String.grap") == {:yes, ~c"heme", []}
  # end

  # test "Elixir completion with self", %{runtime: runtime} do
  #   assert expand(runtime, ~c"Enumerable") == {:yes, ~c".", []}
  # end

  test "Elixir completion on modules from load path", %{runtime: runtime} do
    assert {:yes,
            [%{name: "Stream", kind: :module}, %{name: "String", kind: :module}, %{name: "StringIO", kind: :module}]} =
             expand(runtime, ~c"Str")

    assert {:yes,
            [
              %{name: "Macro", kind: :module},
              %{name: "Map", kind: :module},
              %{name: "MapSet", kind: :module},
              %{name: "MatchError", kind: :module}
            ]} = expand(runtime, ~c"Ma")

    assert {:yes, [%{name: "Dict", kind: :module}]} = expand(runtime, ~c"Dic")

    # FIXME: ExUnit is not available when the MIX_ENV is dev. Need to figure out a way to make it complete later
    # but i guess it does?? i'm confused

    assert {:yes,
            [
              %{name: "ExUnit", kind: :module},
              %{name: "Exception", kind: :module}
            ]} = expand(runtime, ~c"Ex")
  end

  # test "Elixir no completion for underscored functions with no doc", %{runtime: runtime} do
  #   {:module, _, bytecode, _} =
  #     defmodule Elixir.Sample do
  #       @moduledoc false
  #       def __foo__, do: 0
  #       @doc "Bar doc"
  #       def __bar__, do: 1
  #     end

  #   File.write!("Elixir.Sample.beam", bytecode)
  #   assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
  #   assert expand(runtime, ~c"Sample._") == {:yes, ~c"_bar__", []}
  # after
  #   File.rm("Elixir.Sample.beam")
  #   :code.purge(Sample)
  #   :code.delete(Sample)
  # end

  # test "Elixir no completion for default argument functions with doc set to false", %{runtime: runtime} do
  #   {:yes, ~c"", available} = expand(runtime, ~c"String.")
  #   refute Enum.member?(available, ~c"rjust/2")
  #   assert Enum.member?(available, ~c"replace/3")

  #   assert expand(runtime, ~c"String.r") == {:yes, ~c"e", []}

  #   {:module, _, bytecode, _} =
  #     defmodule Elixir.DefaultArgumentFunctions do
  #       @moduledoc false
  #       def foo(a \\ :a, b, c \\ :c), do: {a, b, c}

  #       def _do_fizz(a \\ :a, b, c \\ :c), do: {a, b, c}

  #       @doc false
  #       def __fizz__(a \\ :a, b, c \\ :c), do: {a, b, c}

  #       @doc "bar/0 doc"
  #       def bar, do: :bar
  #       @doc false
  #       def bar(a \\ :a, b, c \\ :c, d \\ :d), do: {a, b, c, d}
  #       @doc false
  #       def bar(a, b, c, d, e), do: {a, b, c, d, e}

  #       @doc false
  #       def baz(a \\ :a), do: {a}

  #       @doc "biz/3 doc"
  #       def biz(a, b, c \\ :c), do: {a, b, c}
  #     end

  #   File.write!("Elixir.DefaultArgumentFunctions.beam", bytecode)
  #   assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(DefaultArgumentFunctions)

  #   functions_list = [~c"bar/0", ~c"biz/2", ~c"biz/3", ~c"foo/1", ~c"foo/2", ~c"foo/3"]
  #   assert expand(runtime, ~c"DefaultArgumentFunctions.") == {:yes, ~c"", functions_list}

  #   assert expand(runtime, ~c"DefaultArgumentFunctions.bi") == {:yes, ~c"z", []}

  #   assert expand(runtime, ~c"DefaultArgumentFunctions.foo") ==
  #            {:yes, ~c"", [~c"foo/1", ~c"foo/2", ~c"foo/3"]}
  # after
  #   File.rm("Elixir.DefaultArgumentFunctions.beam")
  #   :code.purge(DefaultArgumentFunctions)
  #   :code.delete(DefaultArgumentFunctions)
  # end

  test "Elixir no completion", %{runtime: runtime} do
    assert expand(runtime, ~c".") == {:no, []}
    assert expand(runtime, ~c"Xyz") == {:no, []}
    assert expand(runtime, ~c"x.Foo") == {:no, []}
    assert expand(runtime, ~c"x.Foo.get_by") == {:no, []}
    assert expand(runtime, ~c"@foo.bar") == {:no, []}
  end

  test "Elixir root submodule completion", %{runtime: runtime} do
    {:yes, [%{name: "Access", kind: :module}]} = assert expand(runtime, ~c"Elixir.Acce")
  end

  test "Elixir submodule completion", %{runtime: runtime} do
    assert {:yes, [%{name: "Chars", kind: :module}]} = expand(runtime, ~c"String.Cha")
  end

  test "Elixir submodule no completion", %{runtime: runtime} do
    assert expand(runtime, ~c"IEx.Xyz") == {:no, []}
  end

  test "function completion", %{runtime: runtime} do
    assert {:yes, [%{arity: 0, name: "version", kind: :function}]} = expand(runtime, ~c"System.ve")

    assert {:yes, [%{arity: 1, name: "fun2ms", kind: :function}]} = expand(runtime, ~c":ets.fun2")
  end

  test "function completion with arity", %{runtime: runtime} do
    assert {:yes,
            [
              %{arity: 1, name: "printable?", kind: :function},
              %{arity: 2, name: "printable?", kind: :function}
            ]} = expand(runtime, ~c"String.printable?")

    assert {:yes,
            [
              %{arity: 1, name: "printable?", kind: :function},
              %{arity: 2, name: "printable?", kind: :function}
            ]} = expand(runtime, ~c"String.printable?/")

    assert {:yes,
            [
              %{arity: 1, name: "count", kind: :function},
              %{arity: 2, name: "count", kind: :function},
              %{arity: 2, name: "count_until", kind: :function},
              %{arity: 3, name: "count_until", kind: :function}
            ]} = expand(runtime, ~c"Enum.count")

    assert {:yes,
            [
              %{arity: 1, name: "count", kind: :function},
              %{arity: 2, name: "count", kind: :function}
            ]} = expand(runtime, ~c"Enum.count/")
  end

  test "operator completion", %{runtime: runtime} do
    assert {:yes,
            [
              %{arity: 1, name: "+", kind: :function},
              %{arity: 2, name: "+", kind: :function},
              %{arity: 2, name: "++", kind: :function}
            ]} = expand(runtime, ~c"+")

    assert {:yes,
            [
              %{arity: 1, name: "+", kind: :function},
              %{arity: 2, name: "+", kind: :function}
            ]} = expand(runtime, ~c"+/")

    assert {:yes,
            [
              %{arity: 2, name: "++", kind: :function}
            ]} = expand(runtime, ~c"++/")
  end

  test "sigil completion", %{runtime: runtime} do
    assert {:yes, sigils} =
             expand(
               runtime,
               ~c"~",
               Map.merge(base_env(), %{macros: [{Kernel, [sigil_c: 1, sigil_C: 1, sigil_r: 1, foo: 1]}]})
             )

    assert %{name: "C", kind: :sigil} in sigils
    assert {:yes, ~c"", sigils} = expand(runtime, ~c"~r")
    assert ~c"\"" in sigils
    assert ~c"(" in sigils
  end

  # TODO: maps
  # test "map atom key completion is supported", %{runtime: runtime} do
  #   prev = "map = %{foo: 1, bar_1: 23, bar_2: 14}"
  #   assert expand(runtime, ~c"#{prev}\nmap.f") == {:yes, ~c"oo", []}
  #   assert expand(runtime, ~c"map.b") == {:yes, ~c"ar_", []}
  #   assert expand(runtime, ~c"map.bar_") == {:yes, ~c"", [~c"bar_1", ~c"bar_2"]}
  #   assert expand(runtime, ~c"map.c") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map.") == {:yes, ~c"", [~c"bar_1", ~c"bar_2", ~c"foo"]}
  #   assert expand(runtime, ~c"map.foo") == {:no, ~c"", []}
  # end

  # TODO: maps
  # test "nested map atom key completion is supported", %{runtime: runtime} do
  #   prev = "map = %{nested: %{deeply: %{foo: 1, bar_1: 23, bar_2: 14, mod: String, num: 1}}}"
  #   assert expand(runtime, ~c"map.nested.deeply.f") == {:yes, ~c"oo", []}
  #   assert expand(runtime, ~c"map.nested.deeply.b") == {:yes, ~c"ar_", []}
  #   assert expand(runtime, ~c"map.nested.deeply.bar_") == {:yes, ~c"", [~c"bar_1", ~c"bar_2"]}

  #   assert expand(runtime, ~c"map.nested.deeply.") ==
  #            {:yes, ~c"", [~c"bar_1", ~c"bar_2", ~c"foo", ~c"mod", ~c"num"]}

  #   assert expand(runtime, ~c"map.nested.deeply.mod.print") == {:yes, ~c"able?", []}

  #   assert expand(runtime, ~c"map.nested") == {:yes, ~c".", []}
  #   assert expand(runtime, ~c"map.nested.deeply") == {:yes, ~c".", []}
  #   assert expand(runtime, ~c"map.nested.deeply.foo") == {:no, ~c"", []}

  #   assert expand(runtime, ~c"map.nested.deeply.c") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map.a.b.c.f") == {:no, ~c"", []}
  # end

  # TODO: maps
  # test "map string key completion is not supported", %{runtime: runtime} do
  #   prev = ~S(map = %{"foo" => 1})
  #   assert expand(runtime, ~c"map.f") == {:no, ~c"", []}
  # end

  # TODO: maps
  # test "bound variables for modules and maps", %{runtime: runtime} do
  #   prev = "num = 5; map = %{nested: %{num: 23}}"
  #   assert expand(runtime, ~c"num.print") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map.nested.num.f") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map.nested.num.key.f") == {:no, ~c"", []}
  # end

  # TODO: maps
  # test "access syntax is not supported", %{runtime: runtime} do
  #   prev = "map = %{nested: %{deeply: %{num: 23}}}"
  #   assert expand(runtime, ~c"map[:nested][:deeply].n") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map[:nested].deeply.n") == {:no, ~c"", []}
  #   assert expand(runtime, ~c"map.nested.[:deeply].n") == {:no, ~c"", []}
  # end

  test "unbound variables is not supported", %{runtime: runtime} do
    prev = "num = 5"

    assert expand(runtime, ~c"#{prev}\nother_var.f") == {:no, []}

    # assert expand(runtime, ~c"a.b.c.d") == {:no, ~c"", []}
  end

  test "macro completion", %{runtime: runtime} do
    {:yes, list} = expand(runtime, ~c"Kernel.is_")
    assert is_list(list)
  end

  # NOTE: special forms are a.. special case, so they work ootb
  test "imports completion", %{runtime: runtime} do
    {:yes, list} = expand(runtime, ~c"")
    assert is_list(list)

    Enum.any?(list, fn i ->
      match?(%{name: "unquote", arity: 1, kind: :function}, i)
    end)

    Enum.any?(list, fn i ->
      match?(%{name: "try", arity: 1, kind: :function}, i)
    end)
  end

  # test "kernel import completion", %{runtime: runtime} do
  #   assert {:yes, [%{name: "defstruct", kind: :function, arity: 1}]} = expand(runtime, ~c"defstru")

  #   assert {:yes,
  #           [
  #             %{arity: 3, name: "put_elem", kind: :function},
  #             %{arity: 2, name: "put_in", kind: :function},
  #             %{arity: 3, name: "put_in", kind: :function}
  #           ]} = expand(runtime, ~c"put_")
  # end

  test "variable name completion", %{runtime: runtime} do
    prev = "numeral = 3; number = 3; nothing = nil"

    env =
      Map.merge(base_env(), %{
        variables: ["numeral", "number", "nothing"],
        functions: [
          {Kernel,
           [
             node: 0,
             node: 1,
             not: 1,
             +: 1,
             +: 2
           ]}
        ]
      })

    assert expand(runtime, ~c"#{prev}\nnumb", env) == {:yes, [%{name: "number", kind: :variable}]}

    assert expand(runtime, ~c"#{prev}\nnum", env) ==
             {:yes, [%{name: "number", kind: :variable}, %{name: "numeral", kind: :variable}]}

    assert expand(runtime, ~c"#{prev}\nno", env) == {
             :yes,
             [
               %{name: "nothing", kind: :variable},
               %{arity: 0, kind: :function, name: "node", data: {Kernel, "node", 0}},
               %{arity: 1, kind: :function, name: "node", data: {Kernel, "node", 1}},
               %{arity: 1, kind: :function, name: "not", data: {Kernel, "not", 1}}
             ]
           }
  end

  # TODO: locals
  # test "completion of manually imported functions and macros", %{runtime: runtime} do
  #   prev = "import Enum\nimport Supervisor, only: [count_children: 1]\nimport Protocol"

  #   assert expand(runtime, ~c"#{prev}\nder") == {:yes, ~c"ive", []}

  #   assert expand(runtime, ~c"#{prev}\ntake") ==
  #            {:yes, ~c"", [~c"take/2", ~c"take_every/2", ~c"take_random/2", ~c"take_while/2"]}

  #   assert expand(runtime, ~c"#{prev}\ntake/") == {:yes, ~c"", [~c"take/2"]}

  #   assert expand(runtime, ~c"#{prev}\ncount") ==
  #            {:yes, ~c"",
  #             [
  #               ~c"count/1",
  #               ~c"count/2",
  #               ~c"count_children/1",
  #               ~c"count_until/2",
  #               ~c"count_until/3"
  #             ]}

  #   assert expand(runtime, ~c"#{prev}\ncount/") == {:yes, ~c"", [~c"count/1", ~c"count/2"]}
  # end

  # defmacro define_var do
  #   quote(do: var!(my_var_1, Elixir) = 1)
  # end

  # TODO: locals
  # test "ignores quoted variables when performing variable completion", %{runtime: runtime} do
  #   prev = "require #{__MODULE__}; #{__MODULE__}.define_var(); my_var_2 = 2"
  #   assert expand(runtime, ~c"#{prev}\nmy_var") == {:yes, ~c"_2", [%{name: "my_var_2", kind: :variable}]}
  # end

  test "kernel special form completion", %{runtime: runtime} do
    assert {:yes, [%{arity: 1, name: "unquote_splicing", kind: :function}]} = expand(runtime, ~c"unquote_spl")
  end

  test "completion inside expression", %{runtime: runtime} do
    assert {:yes, [%{name: "Enum", kind: :module}, %{name: "Enumerable", kind: :module}]} = expand(runtime, ~c"1 En")

    assert {:yes, [%{name: "Enum", kind: :module}, %{name: "Enumerable", kind: :module}]} = expand(runtime, ~c"Test(En")

    assert {:yes, [%{name: "zlib", kind: :module}]} = expand(runtime, ~c"Test :zl")
    assert {:yes, [%{name: "zlib", kind: :module}]} = expand(runtime, ~c"[:zl")
    assert {:yes, [%{name: "zlib", kind: :module}]} = expand(runtime, ~c"{:zl")
  end

  test "Elixir completion sublevel", %{runtime: runtime} do
    assert expand(runtime, ~c"SublevelTest.") ==
             {:yes, [%{name: "LevelA", data: SublevelTest.LevelA.LevelB, kind: :module}]}
  end

  # TODO: aliases
  # test "complete aliases of Elixir modules", %{runtime: runtime} do
  #   prev = "alias List, as: MyList"
  #   assert expand(runtime, ~c"MyL") == {:yes, ~c"ist", []}
  #   assert expand(runtime, ~c"MyList") == {:yes, ~c".", []}
  #   assert expand(runtime, ~c"MyList.to_integer") == {:yes, [], [~c"to_integer/1", ~c"to_integer/2"]}
  # end

  # TODO: aliases
  # test "complete aliases of Erlang modules", %{runtime: runtime} do
  #   prev = "alias :lists, as: EList"
  #   assert expand(runtime, ~c"#{prev}\nEL") == {:yes, ~c"ist", []}
  #   assert expand(runtime, ~c"#{prev}\nEList") == {:yes, ~c".", []}
  #   assert expand(runtime, ~c"#{prev}\nEList.map") == {:yes, [], [~c"map/2", ~c"mapfoldl/3", ~c"mapfoldr/3"]}
  # end

  # TODO: idk if we need this
  # test "completion for functions added when compiled module is reloaded", %{runtime: runtime} do
  #   {:module, _, bytecode, _} =
  #     defmodule Sample do
  #       @moduledoc false
  #       def foo, do: 0
  #     end

  #   File.write!("Elixir.NextLS.AutocompleteTest.Sample.beam", bytecode)
  #   assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
  #   assert expand(runtime, ~c"NextLS.AutocompleteTest.Sample.foo") == {:yes, ~c"", [~c"foo/0"]}

  #   Code.compiler_options(ignore_module_conflict: true)

  #   defmodule Sample do
  #     @moduledoc false
  #     def foo, do: 0
  #     def foobar, do: 0
  #   end

  #   assert expand(runtime, ~c"NextLS.AutocompleteTest.Sample.foo") == {:yes, ~c"", [~c"foo/0", ~c"foobar/0"]}
  # after
  #   File.rm("Elixir.NextLS.AutocompleteTest.Sample.beam")
  #   Code.compiler_options(ignore_module_conflict: false)
  #   :code.purge(Sample)
  #   :code.delete(Sample)
  # end

  test "completion for struct names", %{runtime: runtime} do
    assert {:yes, entries} = expand(runtime, ~c"%")
    assert %{name: "URI", kind: :struct} in entries
    assert %{name: "IEx.History", kind: :struct} in entries
    assert %{name: "IEx.Server", kind: :struct} in entries

    assert {:yes, entries} = expand(runtime, ~c"%IEx.")
    assert %{name: "IEx.History", kind: :struct} in entries
    assert %{name: "IEx.Server", kind: :struct} in entries

    assert expand(runtime, ~c"%Something.Fo") ==
             {:yes, [%{name: "Something.Foo.MyStruct", kind: :struct}]}

    assert expand(runtime, ~c"%Something.Foo.MyStr") ==
             {:yes, [%{name: "Something.Foo.MyStruct", kind: :struct}]}

    # TODO: aliases
    # prev = "alias NextLS.AutocompleteTest.MyStruct"
    # assert expand(runtime, ~c"%MyStr") == {:yes, ~c"uct{", []}
  end

  test "completion for struct keys", %{runtime: runtime} do
    assert {:yes, entries} = expand(runtime, ~c"%URI{")
    assert %{name: "path", kind: :keyword} in entries
    assert %{name: "query", kind: :keyword} in entries

    assert {:yes, entries} = expand(runtime, ~c"%URI{path: \"foo\",")
    assert %{name: "path", kind: :keyword} not in entries
    assert %{name: "query", kind: :keyword} in entries

    assert {:yes, [%{name: "query", kind: :keyword}]} = expand(runtime, ~c"%URI{path: \"foo\", que")
    assert {:no, []} = expand(runtime, ~c"%URI{path: \"foo\", unkno")
    assert {:no, []} = expand(runtime, ~c"%Unkown{path: \"foo\", unkno")
  end

  test "completion for struct keys in update syntax", %{runtime: runtime} do
    assert {:yes, entries} = expand(runtime, ~c"%URI{var | ")
    assert %{name: "path", kind: :keyword} in entries
    assert %{name: "query", kind: :keyword} in entries

    assert {:yes, entries} = expand(runtime, ~c"%URI{var | path: \"foo\",")
    assert %{name: "path", kind: :keyword} not in entries
    assert %{name: "query", kind: :keyword} in entries

    assert {:yes, [%{name: "query", kind: :keyword}]} = expand(runtime, ~c"%URI{var | path: \"foo\", que")
    assert {:no, []} = expand(runtime, ~c"%URI{var | path: \"foo\", unkno")
    assert {:no, []} = expand(runtime, ~c"%Unkown{var | path: \"foo\", unkno")
  end

  # TODO: this might be possible
  # test "completion for map keys in update syntax", %{runtime: runtime} do
  #   prev = "map = %{some: 1, other: :ok, another: \"qwe\"}"
  #   assert {:yes, ~c"", entries} = expand(runtime, ~c"#{prev}\n%{map | ")
  #   assert ~c"some:" in entries
  #   assert ~c"other:" in entries

  #   assert {:yes, ~c"", entries} = expand(runtime, ~c"#{prev}\n%{map | some: \"foo\",")
  #   assert ~c"some:" not in entries
  #   assert ~c"other:" in entries

  #   assert {:yes, ~c"er: ", []} = expand(runtime, ~c"#{prev}\n%{map | some: \"foo\", oth")
  #   assert {:no,  []} = expand(runtime, ~c"#{prev}\n%{map | some: \"foo\", unkno")
  #   assert {:no,  []} = expand(runtime, ~c"#{prev}\n%{unknown | some: \"foo\", unkno")
  # end

  # TODO: this might be possible
  # test "completion for struct var keys", %{runtime: runtime} do
  #   prev = "struct = %NextLS.AutocompleteTest.MyStruct{}"
  #   assert expand(runtime, ~c"#{prev}\nstruct.my") == {:yes, ~c"_val", []}
  # end

  test "completion for bitstring modifiers", %{runtime: runtime} do
    assert {:yes, entries} = expand(runtime, ~c"<<foo::")
    assert %{name: "integer", kind: :variable} in entries
    assert %{name: "size", kind: :function, arity: 1} in entries

    assert {:yes, [%{name: "integer", kind: :variable}]} = expand(runtime, ~c"<<foo::int")

    assert {:yes, entries} = expand(runtime, ~c"<<foo::integer-")
    refute %{name: "integer", kind: :variable} in entries
    assert %{name: "little", kind: :variable} in entries
    assert %{name: "size", kind: :function, arity: 1} in entries

    assert {:yes, entries} = expand(runtime, ~c"<<foo::integer-little-")
    refute %{name: "integer", kind: :variable} in entries
    refute %{name: "little", kind: :variable} in entries
    assert %{name: "size", kind: :function, arity: 1} in entries
  end

  test "completion for aliases in special forms", %{runtime: runtime} do
    assert {:yes, entries} = expand(runtime, ~c"alias ")
    assert %{name: "Atom", data: Atom, kind: :module} in entries
    refute %{name: "is_atom", kind: :function, arity: 1} in entries

    assert {:yes, [%{name: "Range", kind: :module}]} = expand(runtime, ~c"alias Date.")
  end

  test "ignore invalid Elixir module literals", %{runtime: runtime} do
    assert expand(runtime, ~c"NextLS.AutocompleteTest.Unicod") == {:no, []}
  end

  @tag :skip
  test "signature help for functions and macros", %{runtime: _runtime} do
    # assert expand(runtime, ~c"String.graphemes(") == {:yes, ["graphemes(string)"]}
    # TODO: needs the kernel
    # assert expand(runtime, ~c"def ") == {:yes,  [~c"def(call, expr \\\\ nil)"]}

    # TODO: locals
    # prev = "import Enum; import Protocol"

    # assert ExUnit.CaptureIO.capture_io(fn ->
    #          send(self(), expand(runtime, ~c"reduce("))
    #        end) == "\nreduce(enumerable, acc, fun)"

    # assert_received {:yes,  [~c"reduce(enumerable, fun)"]}

    # assert expand(runtime, ~c"take(") == {:yes,  [~c"take(enumerable, amount)"]}
    # assert expand(runtime, ~c"derive(") == {:yes,  [~c"derive(protocol, module, options \\\\ [])"]}

    # defmodule NoDocs do
    #   @moduledoc false
    #   def sample(a), do: a
    # end

    # assert {:yes, [], [_ | _]} = expand(runtime, ~c"NoDocs.sample(")
  end

  test "path completion inside strings", %{tmp_dir: dir, runtime: runtime} do
    dir |> Path.join("single1") |> File.touch()
    dir |> Path.join("file1") |> File.touch()
    dir |> Path.join("file2") |> File.touch()
    dir |> Path.join("dir") |> File.mkdir()
    dir |> Path.join("dir/file3") |> File.touch()
    dir |> Path.join("dir/file4") |> File.touch()

    assert expand(runtime, ~c"\"./") == path_autocompletion(".", runtime)
    assert expand(runtime, ~c"\"/") == path_autocompletion("/", runtime)
    assert expand(runtime, ~c"\"./#\{") == expand(runtime, ~c"{")
    assert expand(runtime, ~c"\"./#\{Str") == expand(runtime, ~c"{Str")
    assert expand(runtime, ~c"Path.join(\"./\", is_") == expand(runtime, ~c"is_")

    assert expand(runtime, ~c"\"#{dir}/") == path_autocompletion(dir, runtime)
    assert expand(runtime, ~c"\"#{dir}/sin") == {:yes, [%{name: "single1", kind: :file}]}
    assert expand(runtime, ~c"\"#{dir}/single1") == {:yes, [%{name: "single1", kind: :file}]}

    assert {:yes, [_, _] = files} = expand(runtime, ~c"\"#{dir}/fi")
    assert %{name: "file2", kind: :file} in files
    assert %{name: "file1", kind: :file} in files

    assert expand(runtime, ~c"\"#{dir}/file") == path_autocompletion(dir, runtime, "file")
    assert expand(runtime, ~c"\"#{dir}/d") == {:yes, [%{name: "dir/", kind: :dir}]}
    assert expand(runtime, ~c"\"#{dir}/dir") == {:yes, [%{name: "dir/", kind: :dir}]}

    assert {:yes, [_, _] = files} = expand(runtime, ~c"\"#{dir}/dir/")
    assert %{name: "file4", kind: :file} in files
    assert %{name: "file3", kind: :file} in files

    assert expand(runtime, ~c"\"#{dir}/dir/file") == dir |> Path.join("dir") |> path_autocompletion(runtime, "file")
  end

  defp path_autocompletion(dir, runtime, hint \\ "") do
    runtime
    |> NextLS.Runtime.execute!(do: File.ls!(dir))
    |> Stream.filter(&String.starts_with?(&1, hint))
    |> Enum.map(fn file ->
      kind = if File.dir?(Path.join(dir, file)), do: :dir, else: :file
      name = if kind == :dir and not String.ends_with?(file, "/"), do: file <> "/", else: file
      %{name: name, kind: kind}
    end)
    |> case do
      [] -> {:no, []}
      list -> {:yes, list}
    end
  end
end
