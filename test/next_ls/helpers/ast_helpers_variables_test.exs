defmodule NextLS.ASTHelpersVariablesTest do
  use ExUnit.Case, async: true

  alias NextLS.ASTHelpers.Variables

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "my_proj/lib"))
    source = Path.join(tmp_dir, "my_proj/lib/bar.ex")

    File.write!(source, """
    defmodule Bar do
      @alpha 123

      def foo1(%{bravo: bravo} = alpha) when is_nil(bravo) do
        charlie = 1
        %{charlie: ^charlie, delta: delta} = alpha
        {:ok, alpha, bravo, charlie, delta}
      end

      def foo2(charlie) do
        alpha = charlie

        bravo =
          if alpha == @alpha do
            alpha = :ok
            bravo = @alpha
            IO.inspect(alpha)
            IO.inspect(bravo)
          else
            alpha = :error
            IO.inspect(alpha)
          end

        {:ok, alpha, bravo}
      end

      def foo3 do
        alpha = foo4()
        bravo = 1
        charlie = 1

        case alpha do
          :ok = bravo when is_atom(bravo) ->
            charlie = bravo
            IO.inspect(charlie)

          bravo ->
            IO.inspect(bravo)
            :error
        end

        {:ok, bravo, charlie}
      end

      defp foo4 do
        alpha = Enum.random(1..10)
        bravo = :ok

        charlie =
          cond do
            alpha == 5 ->
              bravo

            true ->
              :error
          end

        IO.inspect(alpha)
        charlie
      end

      def foo5(alpha) do
        bravo = 1

        for alpha <- alpha do
          IO.inspect(alpha)
        end

        for bravo <- alpha, charlie <- [1, 2, 3], bravo < charlie do
          IO.inspect(charlie)
        end

        with {:ok, delta} <- alpha,
             [delta, tail] <- delta do
          IO.inspect(delta)
          IO.inspect(tail)
        else
          error -> {:error, error}
        end

        {:ok, bravo, alpha}
      end

      def foo6(alpha) do
        bravo = fn
          charlie, {:ok, delta} = alpha ->
            IO.inspect(alpha)
            {:ok, charlie, delta}

          charlie, {:error, delta} = alpha ->
            IO.inspect(alpha)
            {:error, charlie, delta}
        end

        echo =
          alpha
          |> Enum.map(fn alpha -> {:ok, alpha} end)
          |> Enum.filter(fn alpha -> match?({:ok, _}, alpha) end)

        {:ok, bravo.(1, alpha), echo}
      end

      def foo7(alpha) do
        receive do
          {:selector, bravo, charlie} when is_integer(charlie) ->
            alpha = 1
            {alpha, bravo}

          bravo ->
            {alpha, bravo}
        after
          5000 ->
            IO.puts(alpha)
        end

        charlie = 2
        destructure([alpha, ^charlie], [1, 2, 3])
        IO.inspect(alpha)
      end

      defmacro initialize_to_char_count(variables) do
        Enum.map(variables, fn name ->
          var = Macro.var(name, nil)
          length = name |> Atom.to_string() |> String.length()

          quote do
            unquote(var) = unquote(length)
          end
        end)
      end
    end
    """)

    [source: source]
  end

  describe("get_variable_definition/2") do
    test "symbol defined in a match is found", %{source: source} do
      symbol = Variables.get_variable_definition(source, {7, 25})
      assert symbol == {:charlie, {5..5, 5..12}}
    end

    test "returns nil when position is not a variable reference", %{source: source} do
      symbol = Variables.get_variable_definition(source, {7, 6})
      assert symbol == nil
    end

    test "returns nil when position is a variable symbol", %{source: source} do
      symbol = Variables.get_variable_definition(source, {5, 5})
      assert symbol == nil
    end
  end

  describe("list_variable_references/2") do
    test "references that defined by same symbol as target reference", %{source: source} do
      refs = Variables.list_variable_references(source, {6, 17})
      assert length(refs) == 2
      assert exists_in?(refs, {:charlie, {6..6, 17..24}})
      assert exists_in?(refs, {:charlie, {7..7, 25..32}})
    end

    test "symbol set in a match and corrctly processing ^", %{source: source} do
      refs = Variables.list_variable_references(source, {5, 5})
      assert length(refs) == 2
      assert exists_in?(refs, {:charlie, {6..6, 17..24}})
      assert exists_in?(refs, {:charlie, {7..7, 25..32}})
    end

    test "symbol set in a function arguments", %{source: source} do
      refs = Variables.list_variable_references(source, {4, 30})
      assert length(refs) == 2
      assert exists_in?(refs, {:alpha, {6..6, 42..47}})
      assert exists_in?(refs, {:alpha, {7..7, 11..16}})
    end

    test "symbol set in a function arguments and referenced in 'when' clause", %{source: source} do
      refs = Variables.list_variable_references(source, {4, 21})
      assert length(refs) == 2
      assert exists_in?(refs, {:bravo, {4..4, 49..54}})
      assert exists_in?(refs, {:bravo, {7..7, 18..23}})
    end

    test "symbol set in a mattern match", %{source: source} do
      refs = Variables.list_variable_references(source, {6, 33})
      assert length(refs) == 1
      assert exists_in?(refs, {:delta, {7..7, 34..39}})
    end

    test "references shadowed by 'if/else' blocks", %{source: source} do
      refs = Variables.list_variable_references(source, {11, 5})
      assert length(refs) == 2
      assert exists_in?(refs, {:alpha, {14..14, 10..15}})
      assert exists_in?(refs, {:alpha, {24..24, 11..16}})
    end

    test "symbol set in 'if' block", %{source: source} do
      refs = Variables.list_variable_references(source, {15, 9})
      assert length(refs) == 1
      assert exists_in?(refs, {:alpha, {17..17, 20..25}})
    end

    test "symbol set in match with 'if' containing it's shadow", %{source: source} do
      refs = Variables.list_variable_references(source, {13, 5})
      assert length(refs) == 1
      assert exists_in?(refs, {:bravo, {24..24, 18..23}})
    end

    test "symbol set in 'case' clause", %{source: source} do
      refs = Variables.list_variable_references(source, {33, 13})
      assert length(refs) == 2
      assert exists_in?(refs, {:bravo, {33..33, 32..37}})
      assert exists_in?(refs, {:bravo, {34..34, 19..24}})
    end

    test "symbol referenced in 'cond' clause", %{source: source} do
      refs = Variables.list_variable_references(source, {46, 5})
      assert length(refs) == 2
      assert exists_in?(refs, {:alpha, {51..51, 9..14}})
      assert exists_in?(refs, {:alpha, {58..58, 16..21}})
    end

    test "symbol shadowed in 'for' and 'with'", %{source: source} do
      refs = Variables.list_variable_references(source, {62, 12})
      assert length(refs) == 4
      assert exists_in?(refs, {:alpha, {65..65, 18..23}})
      assert exists_in?(refs, {:alpha, {69..69, 18..23}})
      assert exists_in?(refs, {:alpha, {73..73, 26..31}})
      assert exists_in?(refs, {:alpha, {81..81, 18..23}})

      refs2 = Variables.list_variable_references(source, {63, 5})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:bravo, {81..81, 11..16}})
    end

    test "symbol defined in 'for'", %{source: source} do
      refs = Variables.list_variable_references(source, {65, 9})
      assert length(refs) == 1
      assert exists_in?(refs, {:alpha, {66..66, 18..23}})

      refs2 = Variables.list_variable_references(source, {69, 9})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:bravo, {69..69, 47..52}})

      refs3 = Variables.list_variable_references(source, {69, 25})
      assert length(refs3) == 2
      assert exists_in?(refs3, {:charlie, {69..69, 55..62}})
      assert exists_in?(refs3, {:charlie, {70..70, 18..25}})
    end

    test "symbol defined in 'with'", %{source: source} do
      refs = Variables.list_variable_references(source, {73, 16})
      assert length(refs) == 1
      assert exists_in?(refs, {:delta, {74..74, 27..32}})

      refs2 = Variables.list_variable_references(source, {74, 11})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:delta, {75..75, 18..23}})

      refs3 = Variables.list_variable_references(source, {78, 7})
      assert length(refs3) == 1
      assert exists_in?(refs3, {:error, {78..78, 25..30}})
    end

    test "symbol shadowed by anonymus funciton", %{source: source} do
      refs = Variables.list_variable_references(source, {84, 12})
      assert length(refs) == 2
      assert exists_in?(refs, {:alpha, {96..96, 7..12}})
      assert exists_in?(refs, {:alpha, {100..100, 21..26}})
    end

    test "symbol defined in anonymus funciton", %{source: source} do
      refs = Variables.list_variable_references(source, {86, 7})
      assert length(refs) == 1
      assert exists_in?(refs, {:charlie, {88..88, 15..22}})

      refs2 = Variables.list_variable_references(source, {86, 22})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:delta, {88..88, 24..29}})

      refs3 = Variables.list_variable_references(source, {86, 31})
      assert length(refs3) == 1
      assert exists_in?(refs3, {:alpha, {87..87, 20..25}})

      refs4 = Variables.list_variable_references(source, {97, 22})
      assert length(refs4) == 1
      assert exists_in?(refs4, {:alpha, {97..97, 37..42}})

      refs5 = Variables.list_variable_references(source, {98, 25})
      assert length(refs5) == 1
      assert exists_in?(refs5, {:alpha, {98..98, 51..56}})
    end

    test "symbols with 'receive' macro", %{source: source} do
      refs = Variables.list_variable_references(source, {103, 12})
      assert length(refs) == 2
      assert exists_in?(refs, {:alpha, {110..110, 10..15}})
      assert exists_in?(refs, {:alpha, {113..113, 17..22}})

      refs2 = Variables.list_variable_references(source, {105, 19})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:bravo, {107..107, 17..22}})
    end

    test "symbols set with 'destructure'", %{source: source} do
      refs = Variables.list_variable_references(source, {117, 18})
      assert length(refs) == 1
      assert exists_in?(refs, {:alpha, {118..118, 16..21}})
    end

    test "symbols set in macro", %{source: source} do
      refs = Variables.list_variable_references(source, {121, 37})
      assert length(refs) == 1
      assert exists_in?(refs, {:variables, {122..122, 14..23}})

      refs2 = Variables.list_variable_references(source, {124, 7})
      assert length(refs2) == 1
      assert exists_in?(refs2, {:length, {127..127, 32..38}})

      refs3 = Variables.list_variable_references(source, {123, 7})
      assert length(refs3) == 1
      assert exists_in?(refs3, {:var, {127..127, 17..20}})
    end
  end

  defp exists_in?(results, var), do: Enum.find(results, &(&1 == var))
end
