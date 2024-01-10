defmodule NextLS.CodeActionable do
  # A diagnostic can produce 1 or more code actions, also it would be easier for
  # unsupported diagnostics to return an empty list when gathering the code actions
  # from diagnostics

  defmodule Data do
    defstruct [:diagnostic, :uri, :document]
  end

  @callback to_code_action(arg :: Data.t()) :: [CodeAction.t()]

  def from(:elixir, diagnostic_data) do
    # Note: It could be NextLS.ElixirExtension.CodeAction.from(diagnostic)
    NextLS.ElixirExtension.to_code_action(diagnostic_data)
  end
  def from(:credo, diagnostic_data) do
    NextLS.CredoExtension.to_code_action(diagnostic_data)
  end
end
