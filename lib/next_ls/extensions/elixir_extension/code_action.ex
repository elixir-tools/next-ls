defmodule NextLS.ElixirExtension.CodeAction do
  @moduledoc false

  alias GenLSP.Structures.Diagnostic
  alias NextLS.CodeActionable
  alias NextLS.CodeActionable.Data
  alias NextLS.ElixirExtension.CodeAction.UnusedVariable

  @behaviour CodeActionable

  @impl true
  def from(%Data{} = data) do
    do_code_action(data.diagnostic, data.document, data.uri)
  end

  defp do_code_action(%Diagnostic{data: %{"type" => "unused_variable"}} = diagnostic, file, uri) do
    UnusedVariable.new(diagnostic, file, uri)
  end

  defp do_code_action(_, _, _), do: []
end
