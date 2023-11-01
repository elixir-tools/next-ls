defmodule :_next_ls_private_credo do
  @moduledoc false

  def issues(args, dir) do
    args
    |> Kernel.++(["--working-dir", dir])
    |> Credo.run()
    |> Credo.Execution.get_issues()
  end
end
