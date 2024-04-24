defmodule NextLS.ASTHelpersTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.Position
  alias NextLS.ASTHelpers
  alias NextLS.ASTHelpers.Aliases

  describe "inside?/2" do
    # example full snippet is the outer
    # alias One.Two.{
    #   Three,
    #   Four # this is the target target
    #   ~~~~
    # }
    # alias One.Four
    test "completely inside outer range" do
      outer = {{1, 1}, {4, 1}}
      target = {{3, 3}, {3, 6}}

      assert ASTHelpers.inside?(outer, target)
    end

    test "completely outside outer range" do
      outer = {{1, 1}, {4, 1}}
      target = {{5, 11}, {5, 14}}

      refute ASTHelpers.inside?(outer, target)
    end
  end

  describe "extract_aliases" do
    test "extracts a normal alias" do
      code = """
      defmodule Foo do
        alias One.Two.Three
      end
      """

      start = %{line: 2, col: 3}
      stop = %{line: 2, col: 21}
      ale = :Three

      assert {{2, 9}, {2, 21}} == Aliases.extract_alias_range(code, {start, stop}, ale)
    end

    test "extract an inline multi alias" do
      code = """
      defmodule Foo do
        alias One.Two.{Three, Four}
      end
      """

      start = %{line: 2, col: 3}
      stop = %{line: 2, col: 29}

      assert {{2, 18}, {2, 22}} == Aliases.extract_alias_range(code, {start, stop}, :Three)
      assert {{2, 25}, {2, 28}} == Aliases.extract_alias_range(code, {start, stop}, :Four)
    end

    test "extract a multi line, multi alias" do
      code = """
      defmodule Foo do
        alias One.Four
        alias One.Two.{
          Three,
          Four
        }
      end
      """

      start = %{line: 3, col: 3}
      stop = %{line: 6, col: 3}

      assert {{4, 5}, {4, 9}} == Aliases.extract_alias_range(code, {start, stop}, :Three)
      assert {{5, 5}, {5, 8}} == Aliases.extract_alias_range(code, {start, stop}, :Four)
    end
  end

  describe "get_surrounding_module/2" do
    test "finds the nearest defmodule definition in the ast" do
      {:ok, ast} =
        Spitfire.parse("""
        defmodule Test do
          defmodule Foo do
            def hello(), do: :foo
          end

          defmodule Bar do
            def hello(), do: :bar
          end
        end
        """)

      for {line, character} <- [{0, 2}, {1, 1}, {4, 0}, {5, 1}, {8, 2}] do
        position = %Position{line: line, character: character}

        assert {:ok, {:defmodule, _, [{:__aliases__, _, [:Test]} | _]}} =
                 ASTHelpers.get_surrounding_module(ast, position)
      end

      for {line, character} <- [{1, 2}, {1, 6}, {2, 5}, {3, 3}] do
        position = %Position{line: line, character: character}

        assert {:ok, {:defmodule, _, [{:__aliases__, _, [:Foo]} | _]}} =
                 ASTHelpers.get_surrounding_module(ast, position)
      end

      for {line, character} <- [{5, 4}, {6, 1}, {7, 0}, {7, 3}] do
        position = %Position{line: line, character: character}

        assert {:ok, {:defmodule, _, [{:__aliases__, _, [:Bar]} | _]}} =
                 ASTHelpers.get_surrounding_module(ast, position)
      end
    end

    test "errors out when it can't find a module" do
      {:ok, ast} =
        Spitfire.parse("""
        def foo, do: :bar
        """)

      position = %Position{line: 0, character: 0}
      assert {:error, :not_found} = ASTHelpers.get_surrounding_module(ast, position)
    end
  end
end
