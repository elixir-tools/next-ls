defmodule :_next_ls_private_compiler do
  @moduledoc false

  def compile() do
    # keep stdout on this node
    Process.group_leader(self(), Process.whereis(:user))

    Mix.Task.clear()

    # load the paths for deps and compile them
    # will noop if they are already compiled
    # The mix cli basically runs this before any mix task
    # we have to rerun because we already ran a mix task
    # (mix run), which called this, but we also passed
    # --no-compile, so nothing was compiled, but the
    # task was not re-enabled it seems
    Mix.Task.rerun("deps.loadpaths")
    Mix.Task.rerun("compile", ["--no-protocol-consolidation", "--return-errors"])
  rescue
    e -> {:error, e}
  end
end
