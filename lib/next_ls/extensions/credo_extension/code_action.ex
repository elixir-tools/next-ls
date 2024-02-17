defmodule NextLS.CredoExtension.CodeAction do
  @moduledoc false

  alias NextLS.CodeActionable
  alias NextLS.CodeActionable.Data

  @behaviour CodeActionable

  @impl true
  def from(%Data{} = _data), do: []
end
