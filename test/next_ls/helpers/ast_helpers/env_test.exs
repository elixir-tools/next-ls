defmodule NextLS.ASTHelpers.EnvTest do
  use ExUnit.Case, async: true

  describe "build/2" do
    test "collects simple variables" do
      code = """
      defmodule Foo do
        def one do
          foo = :bar
          
          Enum.map([foo], fn ->
            bar = x

            b
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, %{line: 8, column: 7})

      assert actual.variables == ["foo", "bar"]
    end

    test "collects variables from patterns" do
      code = """
      defmodule Foo do
        def one() do
          %{bar: [one, %{baz: two}]} = Some.thing()
          
          __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

      assert actual.variables == ["two", "one"]
    end

    test "collects variables from 'formal' parameters" do
      code = """
      defmodule Foo do
        def zero(notme) do
          :error
        end

        def one(foo, bar, baz) do
          
          f
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 8, column: 5)

      assert actual.variables == ["baz", "bar", "foo"]
    end

    test "collects variables from stab parameters" do
      code = """
      defmodule Foo do
        def one() do
          Enum.map(Some.thing(), fn
            four ->
              :ok

            one, two, three ->
              o
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 8, column: 9)

      assert actual.variables == ["three", "two", "one"]
    end

    test "collects variables from left stab" do
      code = """
      defmodule Foo do
        def one() do
          with [foo] <- thing(),
               bar <- thang() do
            b
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 5, column: 7)

      assert actual.variables == ["foo", "bar"]
    end

    test "scopes variables lexically" do
      code = """
      defmodule Foo do
        def one() do
          baz = Some.thing()
          foo = Enum.map(two(), fn bar ->
            big_bar = bar * 2
            b
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 6, column: 7)

      assert actual.variables == ["baz", "bar", "big_bar"]
    end

    test "comprehension and with parameters do not leak" do
      code = """
      defmodule Foo do
        def one(entries) do
          with {:ok, entry} <- entries do
            :ok
          end

          for entry <- entries do
            :ok
          end

          e
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 11, column: 5)

      assert actual.variables == ["entries"]
    end

    test "comprehension lhs of generator do not leak into rhs " do
      code = """
      defmodule Foo do
        def one(entries) do
          for entry <- entries,
              not_me <- e do
            :ok
          end
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 4, column: 19)

      assert actual.variables == ["entries", "entry"]
    end

    test "multiple generators and filters in comprehension" do
      code = """
      defmodule Foo do
        def one(entries) do
          for entry <- entries,
              foo = do_something(),
              bar <- foo do
            b
            :ok
          end
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code, line: 6, column: 7)

      assert actual.variables == ["entries", "entry", "foo", "bar"]
    end
  end

  defp run(code, position \\ %{}) do
    zip =
      code
      |> Spitfire.parse(literal_encoder: &{:ok, {:__block__, [{:literal, true} | &2], [&1]}})
      |> then(fn
        {:ok, ast} -> ast
        {:error, ast, _} -> ast
      end)
      |> NextLS.ASTHelpers.find_cursor(Keyword.new(position))

    NextLS.ASTHelpers.Env.build(zip, Map.new(position))
  end
end
