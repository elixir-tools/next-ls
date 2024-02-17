defmodule NextLS.CodeActionable do
  @moduledoc false
  # A diagnostic can produce 1 or more code actions hence we return a list

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic

  defmodule Data do
    @moduledoc false
    defstruct [:diagnostic, :uri, :document]

    @type t :: %__MODULE__{
            diagnostic: Diagnostic.t(),
            uri: String.t(),
            document: String.t()
          }
  end

  @callback from(diagnostic :: Data.t()) :: [CodeAction.t()]

  # TODO: Add support for third party extensions
  def from("elixir", diagnostic_data) do
    NextLS.ElixirExtension.CodeAction.from(diagnostic_data)
  end

  def from("credo", diagnostic_data) do
    NextLS.CredoExtension.CodeAction.from(diagnostic_data)
  end
end
