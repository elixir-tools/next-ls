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

  def compile do
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
      {res, lib_and_test_diagnostics} =
        case compile_all_tests() do
          {:error, test_diagnostics, warnings} ->
            {:error, Enum.into(test_diagnostics ++ warnings, diagnostics, &parse_compiler_diagnostic/1)}

          {_success, _modules, warnings} ->
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
  defp compile_all_tests do
    project = Mix.Project.config()
    test_paths = project[:test_paths] || default_test_paths()
    Enum.each(test_paths, &require_test_helper/1)

    # Finally parse, require and load the files
    test_pattern = project[:test_pattern] || "*_test.exs"
    matched_test_files = Mix.Utils.extract_files(test_paths, test_pattern)

    case Kernel.ParallelCompiler.compile(matched_test_files, return_diagnostics: true) do
      {res, v, %{runtime_warnings: runtime_warnings, compile_warnings: compile_warnings}} ->
        {res, v, runtime_warnings ++ compile_warnings}

      # The `return_diagnostics` option was introduced in Elixir 1.15; earlier
      # versions return tuples which need to be parsed into diagnostics maps
      {res, v, warnings} ->
        {res, v, Enum.map(warnings, &parse_warning/1)}
    end
  rescue
    e -> {:error, e}
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

  defp relative_app_file_exists?(file) do
    {file, _} = ExUnit.Filters.parse_path(file)
    File.exists?(Path.join("../..", file))
  end

  defp require_test_helper(dir) do
    file = Path.join(dir, "test_helper.exs")

    if File.exists?(file) do
      Code.require_file(file)
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
