defmodule NextLSPrivate.DepTracer do
  @moduledoc false

  @source "dep"

  def trace(:start, _env) do
    :ok
  end

  def trace({:on_module, bytecode, _}, env) do
    parent = parent_pid()

    defs = Module.definitions_in(env.module)

    defs =
      for {name, arity} = _def <- defs do
        {name, Module.get_definition(env.module, {name, arity})}
      end

    {:ok, {_, [{~c"Dbgi", bin}]}} = :beam_lib.chunks(bytecode, [~c"Dbgi"])

    {:debug_info_v1, _, {_, %{line: line, struct: struct}, _}} = :erlang.binary_to_term(bin)

    Process.send(
      parent,
      {:tracer,
       %{
         file: env.file,
         module: env.module,
         module_line: line,
         struct: struct,
         defs: defs,
         source: @source
       }},
      []
    )

    :ok
  end

  def trace(_event, _env) do
    :ok
  end

  defp parent_pid do
    "NEXTLS_PARENT_PID" |> System.get_env() |> Base.decode64!() |> :erlang.binary_to_term()
  end
end

defmodule NextLSPrivate.Tracer do
  @moduledoc false

  @source "user"

  def trace(:start, env) do
    Process.send(
      parent_pid(),
      {{:tracer, :start}, env.file},
      []
    )

    :ok
  end

  def trace({:alias, meta, alias, as, _opts}, env) do
    parent = parent_pid()

    Process.send(
      parent,
      {{:tracer, :reference, :alias},
       %{
         meta: meta,
         identifier: as,
         file: env.file,
         type: :alias,
         module: alias,
         source: @source
       }},
      []
    )

    :ok
  end

  def trace({:alias_reference, meta, module}, env) do
    parent = parent_pid()

    alias_map = Map.new(env.aliases, fn {alias, mod} -> {mod, alias} end)

    Process.send(
      parent,
      {{:tracer, :reference},
       %{
         meta: meta,
         identifier: Map.get(alias_map, module, module),
         file: env.file,
         type: :alias,
         module: module,
         source: @source
       }},
      []
    )

    :ok
  end

  def trace({:imported_macro, meta, _module, :@, arity}, env) do
    parent = parent_pid()

    Process.send(
      parent,
      {{:tracer, :reference, :attribute},
       %{
         meta: meta,
         identifier: :@,
         arity: arity,
         file: env.file,
         type: :attribute,
         module: env.module,
         source: @source
       }},
      []
    )

    :ok
  end

  def trace({type, meta, module, func, arity}, env) when type in [:remote_function, :remote_macro, :imported_macro] do
    parent = parent_pid()

    if type == :remote_macro && meta[:closing][:line] != meta[:line] do
      # this is the case that a macro is getting expanded from inside
      # another macro expansion
      :noop
    else
      Process.send(
        parent,
        {{:tracer, :reference},
         %{
           meta: meta,
           identifier: func,
           arity: arity,
           file: env.file,
           type: :function,
           module: module,
           source: @source
         }},
        []
      )
    end

    :ok
  end

  def trace({type, meta, func, arity}, env) when type in [:local_function, :local_macro] do
    parent = parent_pid()

    Process.send(
      parent,
      {{:tracer, :reference},
       %{
         meta: meta,
         identifier: func,
         arity: arity,
         file: env.file,
         type: :function,
         module: env.module,
         source: @source
       }},
      []
    )

    :ok
  end

  def trace({:on_module, bytecode, _}, env) do
    parent = parent_pid()
    # Process.send(parent, {:tracer, :dbg, {:on_module, env}}, [])

    defs = Module.definitions_in(env.module)

    defs =
      for {name, arity} = _def <- defs do
        {name, Module.get_definition(env.module, {name, arity})}
      end

    {:ok, {_, [{~c"Dbgi", bin}]}} = :beam_lib.chunks(bytecode, [~c"Dbgi"])

    {:debug_info_v1, _, {_, %{line: line, struct: struct}, _}} = :erlang.binary_to_term(bin)

    Process.send(
      parent,
      {:tracer,
       %{
         file: env.file,
         module: env.module,
         module_line: line,
         struct: struct,
         defs: defs,
         source: @source
       }},
      []
    )

    :ok
  end

  # def trace(it, env) do
  #   parent = parent_pid()
  #   Process.send(parent, {{:tracer, :dbg}, {it, env.aliases}}, [])
  #   :ok
  # end

  def trace(_event, _env) do
    :ok
  end

  defp parent_pid do
    "NEXTLS_PARENT_PID" |> System.get_env() |> Base.decode64!() |> :erlang.binary_to_term()
  end
end

defmodule :_next_ls_private_compiler do
  @moduledoc false

  @tracers Code.get_compiler_option(:tracers)

  def compile(test_compile_queue) do
    # keep stdout on this node
    Process.group_leader(self(), Process.whereis(:user))
    Code.put_compiler_option(:parser_options, columns: true, token_metadata: true)

    Code.put_compiler_option(:tracers, [NextLSPrivate.DepTracer | @tracers])

    Mix.Task.clear()

    # load the paths for deps and compile them
    # will noop if they are already compiled
    # The mix cli basically runs this before any mix task
    # we have to rerun because we already ran a mix task
    # (mix run), which called this, but we also passed
    # --no-compile, so nothing was compiled, but the
    # task was not re-enabled it seems
    Mix.Task.rerun("deps.loadpaths")

    Code.put_compiler_option(:tracers, [NextLSPrivate.Tracer | @tracers])

    mix_env = "MIX_ENV" |> System.get_env() |> String.to_atom()

    # Load ExUnit before we compile anything in case we are compiling
    # helper modules that depend on ExUnit.
    if mix_env == :test, do: Application.ensure_loaded(:ex_unit)

    {res, diagnostics} =
      Mix.Task.rerun("compile", [
        "--ignore-module-conflict",
        "--no-protocol-consolidation",
        "--return-errors"
      ])

    # Do not compile tests if we're not in the test mix env or elixir
    # compilation fails
    if mix_env != :test or res == :error do
      {res, diagnostics}
    else
      Mix.Task.run("app.start", [])
      {res, lib_and_test_diagnostics} =
        case compile_tests(test_compile_queue) do
          {:error, test_diagnostics, warnings} ->
            {:error, Enum.into(test_diagnostics ++ warnings, diagnostics, &parse_compiler_diagnostic/1)}

          {success, _modules, warnings} when success in [:ok, :noop] ->
            {:ok, Enum.into(warnings, diagnostics, &parse_compiler_diagnostic/1)}
        end

      # After the first compile, we get a redefining module warning for each
      # test module. These are just noise, so we filter them out.
      {res, Enum.reject(lib_and_test_diagnostics, &redefining_module_warning?/1)}
    end
  rescue
    e ->
      {:error, e}
  end

  # Assumes code has already been compiled and :ex_unit has been loaded
  # This implementation is loosely based off the implementation of `mix test`
  defp compile_tests(:all) do
    project = Mix.Project.config()
    test_paths = project[:test_paths] || default_test_paths()
    {res, _v, _warnings} = test_helper_compile_results = test_paths
      |> Enum.map(&compile_test_helper/1)
      |> Enum.map(&parse_compile_results/1)
      |> Enum.reduce(&combine_compiler_results/2)

    # Don't attempt to compile tests if test helpers fail to compile
    if res == :error do
      test_helper_compile_results
    else
      # Finally parse, require and compile the files
      test_pattern = project[:test_pattern] || "*_test.exs"
      matched_test_files = Mix.Utils.extract_files(test_paths, test_pattern)

      combine_compiler_results(test_helper_compile_results, compile_test_files(matched_test_files))
    end
  end

  defp compile_tests([]) do
    {:ok, [], []}
  end

  defp compile_tests(files) do
    compile_test_files(files)
  end

  defp combine_compiler_results({:error, errors1, warnings1}, {:error, errors2, warnings2}) do
    {:error, errors1 ++ errors2, warnings1 ++ warnings2}
  end

  defp combine_compiler_results({:error, errors1, warnings1}, {success, _mods, warnings2}) when success in [:ok, :noop] do
    {:error, errors1, warnings1 ++ warnings2}
  end

  defp combine_compiler_results({success, _mods, warnings1}, {:error, errors2, warnings2}) when success in [:ok, :noop] do
    {:error, errors2, warnings1 ++ warnings2}
  end

  defp combine_compiler_results({success1, mods1, warnings1}, {success2, mods2, warnings2}) when success1 in [:ok, :noop] and success2 in [:ok, :noop] do
    {:ok, mods1 ++ mods2, warnings1 ++ warnings2}
  end

  defp compile_test_files(files) do
    parse_compile_results(Kernel.ParallelCompiler.compile(files, return_diagnostics: true))
  end

  defp parse_compile_results({res, v, %{runtime_warnings: runtime_warnings, compile_warnings: compile_warnings}}) do
    {res, v, runtime_warnings ++ compile_warnings}
  end

  defp parse_compile_results({res, v, warnings}) do
    {res, v, Enum.map(warnings, &parse_warning/1)}
  end

  defp redefining_module_warning?(%Mix.Task.Compiler.Diagnostic{severity: :warning, message: message}) do
    String.starts_with?(message, "redefining module")
  end

  defp redefining_module_warning?(v) do
    false
  end

  defp parse_compiler_diagnostic(m) do
    struct(Mix.Task.Compiler.Diagnostic, Map.put(m, :compiler_name, "Elixir"))
  end

  defp parse_warning({file, position, message}) do
    %{file: file, position: position, message: message, severity: :warning}
  end

  defp compile_test_helper(dir) do
    file = Path.join(dir, "test_helper.exs")

    if File.exists?(file) do
      Kernel.ParallelCompiler.require([file], return_diagnostics: true)
    else
      raise "Cannot run tests because test helper file #{inspect(file)} does not exist"
    end
  end

  defp default_test_paths do
    if File.dir?("test") do
      ["test"]
    else
      []
    end
  end
end
