defmodule NextLS.ElixirExtension.CodeAction do
  @moduledoc false

  @behaviour NextLS.CodeActionable

  alias NextLS.CodeActionable.Data
  alias NextLS.ElixirExtension.CodeAction.UnusedVariable

  @impl true
  def from(%Data{} = data) do
    case data.diagnostic.data do
      %{"type" => "unused_variable"} ->
        UnusedVariable.new(data.diagnostic, data.document, data.uri)

      _ ->
        []
    end
  end
end
