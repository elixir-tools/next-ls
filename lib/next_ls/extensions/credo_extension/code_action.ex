defmodule NextLS.CredoExtension.CodeAction do
  @moduledoc false

  @behaviour NextLS.CodeActionable

  alias NextLS.CodeActionable.Data
  alias NextLS.CredoExtension.CodeAction.RemoveDebugger

  @debug_checks ~w(
    Elixir.Credo.Check.Warning.Dbg
    Elixir.Credo.Check.Warning.IExPry
    Elixir.Credo.Check.Warning.IoInspect
    Elixir.Credo.Check.Warning.IoPuts
    Elixir.Credo.Check.Warning.MixEnv
  )
  @impl true
  def from(%Data{} = data) do
    case data.diagnostic.data do
      %{"check" => check} when check in @debug_checks ->
        RemoveDebugger.new(data.diagnostic, data.document, data.uri)

      _ ->
        []
    end
  end
end
