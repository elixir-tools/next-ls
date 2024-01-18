defmodule NextLS.CodeActionable do
  # A diagnostic can produce 1 or more code actions, also it would be easier for
  # unsupported diagnostics to return an empty list when gathering the code actions
  # from diagnostics

  alias GenLSP.Structures.CodeAction

  defmodule Data do
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
