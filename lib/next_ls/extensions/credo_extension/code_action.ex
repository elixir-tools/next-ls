defmodule NextLS.CredoExtension.CodeAction do
  @moduledoc false

  @behaviour NextLS.CodeActionable

  alias NextLS.CodeActionable.Data

  @impl true
  def from(%Data{} = _data), do: []
end
