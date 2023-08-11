defmodule :_next_ls_private_credo do
  @moduledoc false

  def issues(dir) do
    ["--strict", "--all", "--working-dir", dir]
    |> Credo.run()
    |> Credo.Execution.get_issues()
  end
end

