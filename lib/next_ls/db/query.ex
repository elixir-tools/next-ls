defmodule NextLS.DB.Query do
  @moduledoc false
  defmacro sigil_Q({:<<>>, _, [bin]}, _mods) do
    bin
  end
end
