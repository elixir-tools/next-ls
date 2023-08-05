defmodule NextLS.ASTHelpersTest do
  use ExUnit.Case, async: true

  alias NextLS.ASTHelpers.Aliases

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
        alias One.Two.{
          Three,
          Four
        }
      end
      """

      start = %{line: 2, col: 3}
      stop = %{line: 5, col: 3}

      assert {{3, 5}, {3, 9}} == Aliases.extract_alias_range(code, {start, stop}, :Three)
      assert {{4, 5}, {4, 8}} == Aliases.extract_alias_range(code, {start, stop}, :Four)
    end
  end
end
