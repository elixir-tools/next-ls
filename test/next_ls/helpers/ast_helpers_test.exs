defmodule NextLS.ASTHelpersTest do
  use ExUnit.Case, async: true

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
end
