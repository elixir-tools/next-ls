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
            __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

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
          
          __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

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
              __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

      assert actual.variables == ["three", "two", "one"]
    end

    test "collects variables from left stab" do
      code = """
      defmodule Foo do
        def one() do
          with [foo] <- thing(),
               bar <- thang() do
            __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

      assert actual.variables == ["foo", "bar"]
    end

    test "scopes variables lexically" do
      code = """
      defmodule Foo do
        def one() do
          baz = Some.thing()
          foo = Enum.map(two(), fn bar ->
            big_bar = bar * 2
            __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

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

          __cursor__()
        end

        def two do
          baz = :bar
        end
      end
      """

      actual = run(code)

      assert actual.variables == ["entries"]
    end
  end

  defp run(code) do
    {:ok, zip} =
      code
      |> Spitfire.parse(literal_encoder: &{:ok, {:__literal__, &2, [&1]}})
      |> then(fn
        {:ok, ast} -> ast
        {:error, ast, _} -> ast
      end)
      |> NextLS.ASTHelpers.find_cursor()

    NextLS.ASTHelpers.Env.build(zip)
  end
end
