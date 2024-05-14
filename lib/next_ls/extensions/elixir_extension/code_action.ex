defmodule NextLS.ElixirExtension.CodeAction do
  @moduledoc false

  @behaviour NextLS.CodeActionable

  alias NextLS.CodeActionable.Data
  alias NextLS.ElixirExtension.CodeAction.Require
  alias NextLS.ElixirExtension.CodeAction.UndefinedFunction
  alias NextLS.ElixirExtension.CodeAction.UnusedVariable

  @impl true
  def from(%Data{} = data) do
    case data.diagnostic.data do
      %{"type" => "unused_variable"} ->
        UnusedVariable.new(data.diagnostic, data.document, data.uri)

      %{"type" => "require"} ->
        Require.new(data.diagnostic, data.document, data.uri)

      %{"type" => "undefined-function"} ->
        UndefinedFunction.new(data.diagnostic, data.document, data.uri)

      _ ->
        []
    end
  end
end
