defmodule NextLS.CredoExtension.CodeAction do
  @moduledoc false
  @behaviour CodeActionable

  alias NextLS.CodeActionable
  alias NextLS.CodeActionable.Data

  def from(%Data{} = _data), do: []
end
