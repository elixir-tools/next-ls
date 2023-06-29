defmodule NextLSPrivate.Tracer do
  def trace({:on_module, bytecode, _}, env) do
    parent = "NEXTLS_PARENT_PID" |> System.get_env() |> Base.decode64!() |> :erlang.binary_to_term()

    defs = Module.definitions_in(env.module)

    defs =
      for {name, arity} = _def <- defs do
        {name, Module.get_definition(env.module, {name, arity})}
      end

    {:ok, {_, [{~c"Dbgi", bin}]}} = :beam_lib.chunks(bytecode, [~c"Dbgi"])

    {:debug_info_v1, _, {_, %{line: line, struct: struct}, _}} = :erlang.binary_to_term(bin)

    Process.send(
      parent,
      {:tracer, %{file: env.file, module: env.module, module_line: line, struct: struct, defs: defs}},
      []
    )

    :ok
  end

  def trace(_event, _env) do
    :ok
  end
end

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
    Mix.Task.rerun("compile", ["--no-protocol-consolidation", "--return-errors", "--tracer", "NextLSPrivate.Tracer"])
  rescue
    e -> {:error, e}
  end
end
