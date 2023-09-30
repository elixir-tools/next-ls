defmodule NextLS.AutocompleteTest do
  use ExUnit.Case, async: true

  import NextLS.Support.Utils

  alias NextLS.Runtime

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

    {:ok, broker} =
      Task.start_link(fn ->
        recv = fn recv ->
          receive do
            msg ->
              dbg(msg)
              nil
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
         parent: self(),
         logger: logger,
         db: :some_db,
         mix_env: "dev",
         mix_target: "host",
         registry: __MODULE__.Registry}
      )

    Process.link(pid)

    assert_receive :ready

    Process.put(:broker, broker)

    [runtime: pid, broker: broker]
  end

  defp expand(runtime, expr) do
    NextLS.Autocomplete.expand(Enum.reverse(expr), runtime)
  end

  test "Erlang module completion", %{runtime: runtime} do
    assert expand(runtime, ~c":zl") == {:yes, ~c"ib", []}
  end

  test "Erlang module no completion", %{runtime: runtime} do
    assert expand(runtime, ~c":unknown") == {:no, ~c"", []}
  end

  test "Erlang module multiple values completion", %{runtime: runtime} do
    {:yes, ~c"", list} = expand(runtime, ~c":logger")
    assert ~c"logger" in list
    assert ~c"logger_proxy" in list
  end

  test "Erlang root completion", %{runtime: runtime} do
    {:yes, ~c"", list} = expand(runtime, ~c":")
    assert is_list(list)
    assert ~c"lists" in list
    assert ~c"Elixir.List" not in list
  end

  test "Elixir proxy", %{runtime: runtime} do
    {:yes, ~c"", list} = expand(runtime, ~c"E")
    assert ~c"Elixir" in list
  end

  test "Elixir completion", %{runtime: runtime} do
    assert expand(runtime, ~c"En") == {:yes, ~c"um", []}
    assert expand(runtime, ~c"Enumera") == {:yes, ~c"ble", []}
  end

  test "Elixir type completion", %{runtime: runtime} do
    assert expand(runtime, ~c"t :gen_ser") == {:yes, ~c"ver", []}
    assert expand(runtime, ~c"t String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}

    assert expand(runtime, ~c"t String.") ==
             {:yes, ~c"", [~c"codepoint/0", ~c"grapheme/0", ~c"pattern/0", ~c"t/0"]}

    assert expand(runtime, ~c"t String.grap") == {:yes, ~c"heme", []}
    assert expand(runtime, ~c"t  String.grap") == {:yes, ~c"heme", []}
    assert {:yes, ~c"", [~c"date_time/0" | _]} = expand(runtime, ~c"t :file.")
    assert expand(runtime, ~c"t :file.n") == {:yes, ~c"ame", []}
  end

  test "Elixir callback completion", %{runtime: runtime} do
    assert expand(runtime, ~c"b :strin") == {:yes, ~c"g", []}
    assert expand(runtime, ~c"b String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}
    assert expand(runtime, ~c"b String.") == {:no, ~c"", []}
    assert expand(runtime, ~c"b Access.") == {:yes, ~c"", [~c"fetch/2", ~c"get_and_update/3", ~c"pop/2"]}
    assert expand(runtime, ~c"b GenServer.term") == {:yes, ~c"inate", []}
    assert expand(runtime, ~c"b   GenServer.term") == {:yes, ~c"inate", []}
    assert expand(runtime, ~c"b :gen_server.handle_in") == {:yes, ~c"fo", []}
  end

  test "Elixir helper completion with parentheses", %{runtime: runtime} do
    assert expand(runtime, ~c"t(:gen_ser") == {:yes, ~c"ver", []}
    assert expand(runtime, ~c"t(String") == {:yes, ~c"", [~c"String", ~c"StringIO"]}

    assert expand(runtime, ~c"t(String.") ==
             {:yes, ~c"", [~c"codepoint/0", ~c"grapheme/0", ~c"pattern/0", ~c"t/0"]}

    assert expand(runtime, ~c"t(String.grap") == {:yes, ~c"heme", []}
  end

  test "Elixir completion with self", %{runtime: runtime} do
    assert expand(runtime, ~c"Enumerable") == {:yes, ~c".", []}
  end

  test "Elixir completion on modules from load path", %{runtime: runtime} do
    assert expand(runtime, ~c"Str") == {:yes, [], [~c"Stream", ~c"String", ~c"StringIO"]}
    assert expand(runtime, ~c"Ma") == {:yes, ~c"", [~c"Macro", ~c"Map", ~c"MapSet", ~c"MatchError"]}
    assert expand(runtime, ~c"Dic") == {:yes, ~c"t", []}
    # FIXME: ExUnit is not available when the MIX_ENV is dev. Need to figure out a way to make it complete later
    # assert expand(runtime, ~c"Ex") == {:yes, [], [~c"ExUnit", ~c"Exception"]}
  end

  @tag :pending
  test "Elixir no completion for underscored functions with no doc", %{runtime: runtime} do
    {:module, _, bytecode, _} =
      defmodule Elixir.Sample do
        @moduledoc false
        def __foo__, do: 0
        @doc "Bar doc"
        def __bar__, do: 1
      end

    File.write!("Elixir.Sample.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
    assert expand(runtime, ~c"Sample._") == {:yes, ~c"_bar__", []}
  after
    File.rm("Elixir.Sample.beam")
    :code.purge(Sample)
    :code.delete(Sample)
  end

  test "Elixir no completion for default argument functions with doc set to false", %{runtime: runtime} do
    {:yes, ~c"", available} = expand(runtime, ~c"String.")
    refute Enum.member?(available, ~c"rjust/2")
    assert Enum.member?(available, ~c"replace/3")

    assert expand(runtime, ~c"String.r") == {:yes, ~c"e", []}

    {:module, _, bytecode, _} =
      defmodule Elixir.DefaultArgumentFunctions do
        @moduledoc false
        def foo(a \\ :a, b, c \\ :c), do: {a, b, c}

        def _do_fizz(a \\ :a, b, c \\ :c), do: {a, b, c}

        @doc false
        def __fizz__(a \\ :a, b, c \\ :c), do: {a, b, c}

        @doc "bar/0 doc"
        def bar, do: :bar
        @doc false
        def bar(a \\ :a, b, c \\ :c, d \\ :d), do: {a, b, c, d}
        @doc false
        def bar(a, b, c, d, e), do: {a, b, c, d, e}

        @doc false
        def baz(a \\ :a), do: {a}

        @doc "biz/3 doc"
        def biz(a, b, c \\ :c), do: {a, b, c}
      end

    File.write!("Elixir.DefaultArgumentFunctions.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(DefaultArgumentFunctions)

    functions_list = [~c"bar/0", ~c"biz/2", ~c"biz/3", ~c"foo/1", ~c"foo/2", ~c"foo/3"]
    assert expand(runtime, ~c"DefaultArgumentFunctions.") == {:yes, ~c"", functions_list}

    assert expand(runtime, ~c"DefaultArgumentFunctions.bi") == {:yes, ~c"z", []}

    assert expand(runtime, ~c"DefaultArgumentFunctions.foo") ==
             {:yes, ~c"", [~c"foo/1", ~c"foo/2", ~c"foo/3"]}
  after
    File.rm("Elixir.DefaultArgumentFunctions.beam")
    :code.purge(DefaultArgumentFunctions)
    :code.delete(DefaultArgumentFunctions)
  end

  test "Elixir no completion", %{runtime: runtime} do
    assert expand(runtime, ~c".") == {:no, ~c"", []}
    assert expand(runtime, ~c"Xyz") == {:no, ~c"", []}
    assert expand(runtime, ~c"x.Foo") == {:no, ~c"", []}
    assert expand(runtime, ~c"x.Foo.get_by") == {:no, ~c"", []}
    assert expand(runtime, ~c"@foo.bar") == {:no, ~c"", []}
  end

  test "Elixir root submodule completion", %{runtime: runtime} do
    assert expand(runtime, ~c"Elixir.Acce") == {:yes, ~c"ss", []}
  end

  test "Elixir submodule completion", %{runtime: runtime} do
    assert expand(runtime, ~c"String.Cha") == {:yes, ~c"rs", []}
  end

  test "Elixir submodule no completion", %{runtime: runtime} do
    assert expand(runtime, ~c"IEx.Xyz") == {:no, ~c"", []}
  end

  test "function completion", %{runtime: runtime} do
    assert expand(runtime, ~c"System.ve") == {:yes, ~c"rsion", []}
    assert expand(runtime, ~c":ets.fun2") == {:yes, ~c"ms", []}
  end

  test "function completion with arity", %{runtime: runtime} do
    assert expand(runtime, ~c"String.printable?") == {:yes, ~c"", [~c"printable?/1", ~c"printable?/2"]}
    assert expand(runtime, ~c"String.printable?/") == {:yes, ~c"", [~c"printable?/1", ~c"printable?/2"]}

    assert expand(runtime, ~c"Enum.count") ==
             {:yes, ~c"", [~c"count/1", ~c"count/2", ~c"count_until/2", ~c"count_until/3"]}

    assert expand(runtime, ~c"Enum.count/") == {:yes, ~c"", [~c"count/1", ~c"count/2"]}
  end

  test "operator completion", %{runtime: runtime} do
    assert expand(runtime, ~c"+") == {:yes, ~c"", [~c"+/1", ~c"+/2", ~c"++/2"]}
    assert expand(runtime, ~c"+/") == {:yes, ~c"", [~c"+/1", ~c"+/2"]}
    assert expand(runtime, ~c"++/") == {:yes, ~c"", [~c"++/2"]}
  end

  test "sigil completion", %{runtime: runtime} do
    {:yes, ~c"", sigils} = expand(runtime, ~c"~")
    assert ~c"~C (sigil_C)" in sigils
    {:yes, ~c"", sigils} = expand(runtime, ~c"~r")
    assert ~c"\"" in sigils
    assert ~c"(" in sigils
  end

  @tag :pending
  test "map atom key completion is supported", %{runtime: runtime} do
    prev = "map = %{foo: 1, bar_1: 23, bar_2: 14}"
    assert expand(runtime, ~c"#{prev}\nmap.f") == {:yes, ~c"oo", []}
    # assert expand(runtime, ~c"map.b") == {:yes, ~c"ar_", []}
    # assert expand(runtime, ~c"map.bar_") == {:yes, ~c"", [~c"bar_1", ~c"bar_2"]}
    # assert expand(runtime, ~c"map.c") == {:no, ~c"", []}
    # assert expand(runtime, ~c"map.") == {:yes, ~c"", [~c"bar_1", ~c"bar_2", ~c"foo"]}
    # assert expand(runtime, ~c"map.foo") == {:no, ~c"", []}
  end

  @tag :pending
  test "nested map atom key completion is supported", %{runtime: runtime} do
    prev = "map = %{nested: %{deeply: %{foo: 1, bar_1: 23, bar_2: 14, mod: String, num: 1}}}"
    assert expand(runtime, ~c"map.nested.deeply.f") == {:yes, ~c"oo", []}
    assert expand(runtime, ~c"map.nested.deeply.b") == {:yes, ~c"ar_", []}
    assert expand(runtime, ~c"map.nested.deeply.bar_") == {:yes, ~c"", [~c"bar_1", ~c"bar_2"]}

    assert expand(runtime, ~c"map.nested.deeply.") ==
             {:yes, ~c"", [~c"bar_1", ~c"bar_2", ~c"foo", ~c"mod", ~c"num"]}

    assert expand(runtime, ~c"map.nested.deeply.mod.print") == {:yes, ~c"able?", []}

    assert expand(runtime, ~c"map.nested") == {:yes, ~c".", []}
    assert expand(runtime, ~c"map.nested.deeply") == {:yes, ~c".", []}
    assert expand(runtime, ~c"map.nested.deeply.foo") == {:no, ~c"", []}

    assert expand(runtime, ~c"map.nested.deeply.c") == {:no, ~c"", []}
    assert expand(runtime, ~c"map.a.b.c.f") == {:no, ~c"", []}
  end

  @tag :pending
  test "map string key completion is not supported", %{runtime: runtime} do
    prev = ~S(map = %{"foo" => 1})
    assert expand(runtime, ~c"map.f") == {:no, ~c"", []}
  end

  @tag :pending
  test "bound variables for modules and maps", %{runtime: runtime} do
    prev = "num = 5; map = %{nested: %{num: 23}}"
    assert expand(runtime, ~c"num.print") == {:no, ~c"", []}
    assert expand(runtime, ~c"map.nested.num.f") == {:no, ~c"", []}
    assert expand(runtime, ~c"map.nested.num.key.f") == {:no, ~c"", []}
  end

  @tag :pending
  test "access syntax is not supported", %{runtime: runtime} do
    prev = "map = %{nested: %{deeply: %{num: 23}}}"
    assert expand(runtime, ~c"map[:nested][:deeply].n") == {:no, ~c"", []}
    assert expand(runtime, ~c"map[:nested].deeply.n") == {:no, ~c"", []}
    assert expand(runtime, ~c"map.nested.[:deeply].n") == {:no, ~c"", []}
  end

  @tag :pending
  test "unbound variables is not supported", %{runtime: runtime} do
    prev = "num = 5"

    assert expand(runtime, dbg(~c"#{prev}\nother_var.f")) == {:no, ~c"", []}

    # assert expand(runtime, ~c"a.b.c.d") == {:no, ~c"", []}
  end

  test "macro completion", %{runtime: runtime} do
    {:yes, ~c"", list} = expand(runtime, ~c"Kernel.is_")
    assert is_list(list)
  end

  test "imports completion", %{runtime: runtime} do
    {:yes, ~c"", list} = expand(runtime, ~c"")
    assert is_list(list)
    assert ~c"h/1" in list
    assert ~c"unquote/1" in list
    assert ~c"pwd/0" in list
  end

  test "kernel import completion", %{runtime: runtime} do
    assert expand(runtime, ~c"defstru") == {:yes, ~c"ct", []}
    assert expand(runtime, ~c"put_") == {:yes, ~c"", [~c"put_elem/3", ~c"put_in/2", ~c"put_in/3"]}
  end

  test "variable name completion", %{runtime: runtime} do
    prev = "numeral = 3; number = 3; nothing = nil"
    assert expand(runtime, dbg(~c"#{prev}\nnumb")) == {:yes, ~c"er", []}
    assert expand(runtime, ~c"#{prev}\nnum") == {:yes, ~c"", [~c"number", ~c"numeral"]}
    # FIXME: variables + local functions
    # assert expand(runtime, ~c"#{prev}\nno") == {:yes, ~c"", [~c"nothing", ~c"node/0", ~c"node/1", ~c"not/1"]}
  end

  test "completion of manually imported functions and macros", %{runtime: runtime} do
    prev = "import Enum\nimport Supervisor, only: [count_children: 1]\nimport Protocol"

    assert expand(runtime, ~c"#{prev}\nder") == {:yes, ~c"ive", []}

    assert expand(runtime, ~c"#{prev}\ntake") ==
             {:yes, ~c"", [~c"take/2", ~c"take_every/2", ~c"take_random/2", ~c"take_while/2"]}

    assert expand(runtime, ~c"#{prev}\ntake/") == {:yes, ~c"", [~c"take/2"]}

    assert expand(runtime, ~c"#{prev}\ncount") ==
             {:yes, ~c"",
              [
                ~c"count/1",
                ~c"count/2",
                ~c"count_children/1",
                ~c"count_until/2",
                ~c"count_until/3"
              ]}

    assert expand(runtime, ~c"#{prev}\ncount/") == {:yes, ~c"", [~c"count/1", ~c"count/2"]}
  end

  defmacro define_var do
    quote(do: var!(my_var_1, Elixir) = 1)
  end

  test "ignores quoted variables when performing variable completion", %{runtime: runtime} do
    prev = "require #{__MODULE__}; #{__MODULE__}.define_var(); my_var_2 = 2"
    assert expand(runtime, ~c"my_var") == {:yes, ~c"_2", []}
  end

  test "kernel special form completion", %{runtime: runtime} do
    assert expand(runtime, ~c"unquote_spl") == {:yes, ~c"icing", []}
  end

  test "completion inside expression", %{runtime: runtime} do
    assert expand(runtime, ~c"1 En") == {:yes, ~c"um", []}
    assert expand(runtime, ~c"Test(En") == {:yes, ~c"um", []}
    assert expand(runtime, ~c"Test :zl") == {:yes, ~c"ib", []}
    assert expand(runtime, ~c"[:zl") == {:yes, ~c"ib", []}
    assert expand(runtime, ~c"{:zl") == {:yes, ~c"ib", []}
  end

  defmodule SublevelTest.LevelA.LevelB do
    @moduledoc false
  end

  test "Elixir completion sublevel", %{runtime: runtime} do
    assert expand(runtime, ~c"NextLS.AutocompleteTest.SublevelTest.") == {:yes, ~c"LevelA", []}
  end

  test "complete aliases of Elixir modules", %{runtime: runtime} do
    prev = "alias List, as: MyList"
    assert expand(runtime, ~c"MyL") == {:yes, ~c"ist", []}
    assert expand(runtime, ~c"MyList") == {:yes, ~c".", []}
    assert expand(runtime, ~c"MyList.to_integer") == {:yes, [], [~c"to_integer/1", ~c"to_integer/2"]}
  end

  test "complete aliases of Erlang modules", %{runtime: runtime} do
    prev = "alias :lists, as: EList"
    assert expand(runtime, ~c"#{prev}\nEL") == {:yes, ~c"ist", []}
    assert expand(runtime, ~c"#{prev}\nEList") == {:yes, ~c".", []}
    assert expand(runtime, ~c"#{prev}\nEList.map") == {:yes, [], [~c"map/2", ~c"mapfoldl/3", ~c"mapfoldr/3"]}
  end

  test "completion for functions added when compiled module is reloaded", %{runtime: runtime} do
    {:module, _, bytecode, _} =
      defmodule Sample do
        @moduledoc false
        def foo, do: 0
      end

    File.write!("Elixir.NextLS.AutocompleteTest.Sample.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
    assert expand(runtime, ~c"NextLS.AutocompleteTest.Sample.foo") == {:yes, ~c"", [~c"foo/0"]}

    Code.compiler_options(ignore_module_conflict: true)

    defmodule Sample do
      @moduledoc false
      def foo, do: 0
      def foobar, do: 0
    end

    assert expand(runtime, ~c"NextLS.AutocompleteTest.Sample.foo") == {:yes, ~c"", [~c"foo/0", ~c"foobar/0"]}
  after
    File.rm("Elixir.NextLS.AutocompleteTest.Sample.beam")
    Code.compiler_options(ignore_module_conflict: false)
    :code.purge(Sample)
    :code.delete(Sample)
  end

  defmodule MyStruct do
    @moduledoc false
    defstruct [:my_val]
  end

  test "completion for struct names", %{runtime: runtime} do
    assert {:yes, ~c"", entries} = expand(runtime, ~c"%")
    assert ~c"URI" in entries
    assert ~c"IEx.History" in entries
    assert ~c"IEx.Server" in entries

    assert {:yes, ~c"", entries} = expand(runtime, ~c"%IEx.")
    assert ~c"IEx.History" in entries
    assert ~c"IEx.Server" in entries

    assert expand(runtime, ~c"%IEx.AutocompleteTe") == {:yes, ~c"st.MyStruct{", []}
    assert expand(runtime, ~c"%NextLS.AutocompleteTest.MyStr") == {:yes, ~c"uct{", []}

    prev = "alias NextLS.AutocompleteTest.MyStruct"
    assert expand(runtime, ~c"%MyStr") == {:yes, ~c"uct{", []}
  end

  test "completion for struct keys", %{runtime: runtime} do
    assert {:yes, ~c"", entries} = expand(runtime, ~c"%URI{")
    assert ~c"path:" in entries
    assert ~c"query:" in entries

    assert {:yes, ~c"", entries} = expand(runtime, ~c"%URI{path: \"foo\",")
    assert ~c"path:" not in entries
    assert ~c"query:" in entries

    assert {:yes, ~c"ry: ", []} = expand(runtime, ~c"%URI{path: \"foo\", que")
    assert {:no, [], []} = expand(runtime, ~c"%URI{path: \"foo\", unkno")
    assert {:no, [], []} = expand(runtime, ~c"%Unkown{path: \"foo\", unkno")
  end

  test "completion for struct keys in update syntax", %{runtime: runtime} do
    assert {:yes, ~c"", entries} = expand(runtime, ~c"%URI{var | ")
    assert ~c"path:" in entries
    assert ~c"query:" in entries

    assert {:yes, ~c"", entries} = expand(runtime, ~c"%URI{var | path: \"foo\",")
    assert ~c"path:" not in entries
    assert ~c"query:" in entries

    assert {:yes, ~c"ry: ", []} = expand(runtime, ~c"%URI{var | path: \"foo\", que")
    assert {:no, [], []} = expand(runtime, ~c"%URI{var | path: \"foo\", unkno")
    assert {:no, [], []} = expand(runtime, ~c"%Unkown{var | path: \"foo\", unkno")
  end

  test "completion for map keys in update syntax", %{runtime: runtime} do
    prev = "map = %{some: 1, other: :ok, another: \"qwe\"}"
    assert {:yes, ~c"", entries} = expand(runtime, ~c"%{map | ")
    assert ~c"some:" in entries
    assert ~c"other:" in entries

    assert {:yes, ~c"", entries} = expand(runtime, ~c"%{map | some: \"foo\",")
    assert ~c"some:" not in entries
    assert ~c"other:" in entries

    assert {:yes, ~c"er: ", []} = expand(runtime, ~c"%{map | some: \"foo\", oth")
    assert {:no, [], []} = expand(runtime, ~c"%{map | some: \"foo\", unkno")
    assert {:no, [], []} = expand(runtime, ~c"%{unknown | some: \"foo\", unkno")
  end

  test "completion for struct var keys", %{runtime: runtime} do
    prev = "struct = %NextLS.AutocompleteTest.MyStruct{}"
    assert expand(runtime, ~c"struct.my") == {:yes, ~c"_val", []}
  end

  test "completion for bitstring modifiers", %{runtime: runtime} do
    assert {:yes, ~c"", entries} = expand(runtime, ~c"<<foo::")
    assert ~c"integer" in entries
    assert ~c"size/1" in entries

    assert {:yes, ~c"eger", []} = expand(runtime, ~c"<<foo::int")

    assert {:yes, ~c"", entries} = expand(runtime, ~c"<<foo::integer-")
    refute ~c"integer" in entries
    assert ~c"little" in entries
    assert ~c"size/1" in entries

    assert {:yes, ~c"", entries} = expand(runtime, ~c"<<foo::integer-little-")
    refute ~c"integer" in entries
    refute ~c"little" in entries
    assert ~c"size/1" in entries
  end

  test "completion for aliases in special forms", %{runtime: runtime} do
    assert {:yes, ~c"", entries} = expand(runtime, ~c"alias ")
    assert ~c"Atom" in entries
    refute ~c"is_atom" in entries

    assert {:yes, ~c"Range", []} = expand(runtime, ~c"alias Date.")
  end

  test "ignore invalid Elixir module literals", %{runtime: runtime} do
    defmodule(:"Elixir.NextLS.AutocompleteTest.Unicodé", do: nil)
    assert expand(runtime, ~c"NextLS.AutocompleteTest.Unicod") == {:no, ~c"", []}
  after
    :code.purge(:"Elixir.NextLS.AutocompleteTest.Unicodé")
    :code.delete(:"Elixir.NextLS.AutocompleteTest.Unicodé")
  end

  test "signature help for functions and macros", %{runtime: runtime} do
    assert expand(runtime, ~c"String.graphemes(") == {:yes, ~c"", [~c"graphemes(string)"]}
    assert expand(runtime, ~c"def ") == {:yes, ~c"", [~c"def(call, expr \\\\ nil)"]}

    prev = "import Enum; import Protocol"

    assert ExUnit.CaptureIO.capture_io(fn ->
             send(self(), expand(runtime, ~c"reduce("))
           end) == "\nreduce(enumerable, acc, fun)"

    assert_received {:yes, ~c"", [~c"reduce(enumerable, fun)"]}

    assert expand(runtime, ~c"take(") == {:yes, ~c"", [~c"take(enumerable, amount)"]}
    assert expand(runtime, ~c"derive(") == {:yes, ~c"", [~c"derive(protocol, module, options \\\\ [])"]}

    defmodule NoDocs do
      @moduledoc false
      def sample(a), do: a
    end

    assert {:yes, [], [_ | _]} = expand(runtime, ~c"NoDocs.sample(")
  end

  test "path completion inside strings", %{tmp_dir: dir, runtime: runtime} do
    dir |> Path.join("single1") |> File.touch()
    dir |> Path.join("file1") |> File.touch()
    dir |> Path.join("file2") |> File.touch()
    dir |> Path.join("dir") |> File.mkdir()
    dir |> Path.join("dir/file3") |> File.touch()
    dir |> Path.join("dir/file4") |> File.touch()

    assert expand(runtime, ~c"\"./") == path_autocompletion(".")
    assert expand(runtime, ~c"\"/") == path_autocompletion("/")
    assert expand(runtime, ~c"\"./#\{") == expand(runtime, ~c"{")
    assert expand(runtime, ~c"\"./#\{Str") == expand(runtime, ~c"{Str")
    assert expand(runtime, ~c"Path.join(\"./\", is_") == expand(runtime, ~c"is_")

    assert expand(runtime, ~c"\"#{dir}/") == path_autocompletion(dir)
    assert expand(runtime, ~c"\"#{dir}/sin") == {:yes, ~c"gle1", []}
    assert expand(runtime, ~c"\"#{dir}/single1") == {:yes, ~c"\"", []}
    assert expand(runtime, ~c"\"#{dir}/fi") == {:yes, ~c"le", []}
    assert expand(runtime, ~c"\"#{dir}/file") == path_autocompletion(dir, "file")
    assert expand(runtime, ~c"\"#{dir}/d") == {:yes, ~c"ir/", []}
    assert expand(runtime, ~c"\"#{dir}/dir") == {:yes, ~c"/", []}
    assert expand(runtime, ~c"\"#{dir}/dir/") == {:yes, ~c"file", []}
    assert expand(runtime, ~c"\"#{dir}/dir/file") == dir |> Path.join("dir") |> path_autocompletion("file")
  end

  defp path_autocompletion(dir, hint \\ "") do
    dir
    |> File.ls!()
    |> Stream.filter(&String.starts_with?(&1, hint))
    |> Enum.map(&String.to_charlist/1)
    |> case do
      [] -> {:no, ~c"", []}
      list -> {:yes, ~c"", list}
    end
  end
end
