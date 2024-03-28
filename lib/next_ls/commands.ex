defmodule NextLS.Commands do
  @moduledoc false

  @labels %{
    "from-pipe" => "Inlined pipe",
    "to-pipe" => "Extracted to a pipe",
    "alias-refactor" => "Refactored with an alias"
  }
  @doc "Creates a label for the workspace apply struct from the command name"
  def label(command) when is_map_key(@labels, command), do: @labels[command]

  def label(command) do
    raise ArgumentError, "command #{inspect(command)} not supported"
  end
end
