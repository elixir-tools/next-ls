defmodule NextLS.Check do
  @moduledoc """
  Data structures used for NextLS checks.
  """

  @doc """
  Data structure that holds information related to an instance of a check found by NextLS.
  """
  defstruct [:check, :diagnostic, :uri, :document]

  def new(opts) do
    opts = Keyword.update!(opts, :check, &String.to_existing_atom/1)
    struct(__MODULE__, opts)
  end

  defimpl NextLS.CodeActionable do
    alias NextLS.CodeAction

    # TODO: Rough draft of converting a check -> code action
    # def fetch(%{check: UnusedVar} = check) do
    #   [
    #     CodeAction.UnusedVar.new(check)
    #   ]
    # end

    def fetch(_check) do
      []
    end
  end
end
