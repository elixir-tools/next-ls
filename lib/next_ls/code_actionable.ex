defmodule NextLS.CodeActionable do
  @moduledoc false
  # A diagnostic can produce 1 or more code actions hence we return a list

  alias GenLSP.Structures.CodeAction

  defmodule Data do
    @moduledoc false
    defstruct [:diagnostic, :uri, :document]
  end

  @callback from(diagnostic :: Data.t()) :: [CodeAction.t()]

  def from("elixir", diagnostic_data) do
    NextLS.ElixirExtension.CodeAction.from(diagnostic_data)
  end

  def from("credo", diagnostic_data) do
    NextLS.CredoExtension.CodeAction.from(diagnostic_data)
  end
end
