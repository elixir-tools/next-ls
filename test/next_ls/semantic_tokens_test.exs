defmodule NextLS.DocsTest do
  use ExUnit.Case, async: true

  alias NextLS.SemanticTokens

  describe "parameters" do
    test "it returns an encoding of the parameters" do
      code =
        String.split(
          """
          defmodule TestSemanticTokens do
            def hello(var) do
             "Hello " <> var
            end
          end
          """,
          "\n"
        )

      tokens = SemanticTokens.new(code)

      data = Enum.chunk_every(tokens.data, 5)
      modifier = 0
      parameter = 0

      # var 1 is on line 1, char 12

      assert [
               [1, 12, 3, parameter, modifier],
               [1, 15, 3, parameter, modifier]
             ] == data
    end
  end
end
