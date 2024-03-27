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

# vendored from Elixir, Apache 2 license
defmodule :_next_ls_private_formatter do
  @moduledoc false
  @switches [
    check_equivalent: :boolean,
    check_formatted: :boolean,
    no_exit: :boolean,
    dot_formatter: :string,
    dry_run: :boolean,
    stdin_filename: :string
  ]

  @manifest "cached_dot_formatter"
  @manifest_vsn 2

  @newline "\n"
  @blank " "

  @separator "|"
  @cr "↵"
  @line_num_pad @blank

  @gutter [
    del: " -",
    eq: "  ",
    ins: " +",
    skip: "  "
  ]

  @colors [
    del: [text: :red, space: :red_background],
    ins: [text: :green, space: :green_background]
  ]

  @callback features(Keyword.t()) :: [sigils: [atom()], extensions: [binary()]]

  @callback format(String.t(), Keyword.t()) :: String.t()

  @impl true
  def run(args) do
    cwd = File.cwd!()
    {opts, args} = OptionParser.parse!(args, strict: @switches)
    {dot_formatter, formatter_opts} = eval_dot_formatter(cwd, opts)

    if opts[:check_equivalent] do
      IO.warn("--check-equivalent has been deprecated and has no effect")
    end

    if opts[:no_exit] && !opts[:check_formatted] do
      Mix.raise("--no-exit can only be used together with --check-formatted")
    end

    {formatter_opts_and_subs, _sources} =
      eval_deps_and_subdirectories(cwd, dot_formatter, formatter_opts, [dot_formatter])

    formatter_opts_and_subs = load_plugins(formatter_opts_and_subs)

    args
    |> expand_args(cwd, dot_formatter, formatter_opts_and_subs, opts)
    |> Task.async_stream(&format_file(&1, opts), ordered: false, timeout: :infinity)
    |> Enum.reduce({[], []}, &collect_status/2)
    |> check!(opts)
  end

  defp load_plugins({formatter_opts, subs}) do
    plugins = Keyword.get(formatter_opts, :plugins, [])

    if not is_list(plugins) do
      Mix.raise("Expected :plugins to return a list of modules, got: #{inspect(plugins)}")
    end

    # if plugins != [] do
    #   Mix.Task.run("loadpaths", [])
    # end

    # if not Enum.all?(plugins, &Code.ensure_loaded?/1) do
    #   Mix.Task.run("compile", [])
    # end

    for plugin <- plugins do
      cond do
        not Code.ensure_loaded?(plugin) ->
          Mix.raise("Formatter plugin #{inspect(plugin)} cannot be found")

        not function_exported?(plugin, :features, 1) ->
          Mix.raise("Formatter plugin #{inspect(plugin)} does not define features/1")

        true ->
          :ok
      end
    end

    sigils =
      for plugin <- plugins,
          sigil <- find_sigils_from_plugins(plugin, formatter_opts),
          do: {sigil, plugin}

    sigils =
      sigils
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {sigil, plugins} ->
        {sigil,
         fn input, opts ->
           Enum.reduce(plugins, input, fn plugin, input ->
             plugin.format(input, opts ++ formatter_opts)
           end)
         end}
      end)

    {Keyword.put(formatter_opts, :sigils, sigils), Enum.map(subs, fn {path, opts} -> {path, load_plugins(opts)} end)}
  end

  def formatter_for_file(file, opts \\ []) do
    cwd = Keyword.get_lazy(opts, :root, &File.cwd!/0)
    {dot_formatter, formatter_opts} = eval_dot_formatter(cwd, opts)

    {formatter_opts_and_subs, _sources} =
      eval_deps_and_subdirectories(cwd, dot_formatter, formatter_opts, [dot_formatter])

    formatter_opts_and_subs = load_plugins(formatter_opts_and_subs)

    find_formatter_and_opts_for_file(Path.expand(file, cwd), formatter_opts_and_subs)
  end

  defp eval_dot_formatter(cwd, opts) do
    cond do
      dot_formatter = opts[:dot_formatter] ->
        {dot_formatter, eval_file_with_keyword_list(dot_formatter)}

      File.regular?(Path.join(cwd, ".formatter.exs")) ->
        dot_formatter = Path.join(cwd, ".formatter.exs")
        {".formatter.exs", eval_file_with_keyword_list(dot_formatter)}

      true ->
        {".formatter.exs", []}
    end
  end

  # This function reads exported configuration from the imported
  # dependencies and subdirectories and deals with caching the result
  # of reading such configuration in a manifest file.
  defp eval_deps_and_subdirectories(cwd, dot_formatter, formatter_opts, sources) do
    deps = Keyword.get(formatter_opts, :import_deps, [])
    subs = Keyword.get(formatter_opts, :subdirectories, [])

    if not is_list(deps) do
      Mix.raise("Expected :import_deps to return a list of dependencies, got: #{inspect(deps)}")
    end

    if not is_list(subs) do
      Mix.raise("Expected :subdirectories to return a list of directories, got: #{inspect(subs)}")
    end

    if deps == [] and subs == [] do
      {{formatter_opts, []}, sources}
    else
      manifest = Path.join(Mix.Project.manifest_path(), @manifest)

      {{locals_without_parens, subdirectories}, sources} =
        maybe_cache_in_manifest(dot_formatter, manifest, fn ->
          {subdirectories, sources} = eval_subs_opts(subs, cwd, sources)
          {{eval_deps_opts(deps), subdirectories}, sources}
        end)

      formatter_opts =
        Keyword.update(
          formatter_opts,
          :locals_without_parens,
          locals_without_parens,
          &(locals_without_parens ++ &1)
        )

      {{formatter_opts, subdirectories}, sources}
    end
  end

  defp maybe_cache_in_manifest(dot_formatter, manifest, fun) do
    cond do
      is_nil(Mix.Project.get()) or dot_formatter != ".formatter.exs" -> fun.()
      entry = read_manifest(manifest) -> entry
      true -> write_manifest!(manifest, fun.())
    end
  end

  defp read_manifest(manifest) do
    with {:ok, binary} <- File.read(manifest),
         {:ok, {@manifest_vsn, entry, sources}} <- safe_binary_to_term(binary),
         expanded_sources = Enum.flat_map(sources, &Path.wildcard(&1, match_dot: true)),
         false <- Mix.Utils.stale?([Mix.Project.config_mtime() | expanded_sources], [manifest]) do
      {entry, sources}
    else
      _ -> nil
    end
  end

  defp safe_binary_to_term(binary) do
    {:ok, :erlang.binary_to_term(binary)}
  rescue
    _ -> :error
  end

  defp write_manifest!(manifest, {entry, sources}) do
    File.mkdir_p!(Path.dirname(manifest))
    File.write!(manifest, :erlang.term_to_binary({@manifest_vsn, entry, sources}))
    {entry, sources}
  end

  defp eval_deps_opts([]) do
    []
  end

  defp eval_deps_opts(deps) do
    deps_paths = Mix.Project.deps_paths()

    for dep <- deps,
        dep_path = assert_valid_dep_and_fetch_path(dep, deps_paths),
        dep_dot_formatter = Path.join(dep_path, ".formatter.exs"),
        File.regular?(dep_dot_formatter),
        dep_opts = eval_file_with_keyword_list(dep_dot_formatter),
        parenless_call <- dep_opts[:export][:locals_without_parens] || [],
        uniq: true,
        do: parenless_call
  end

  defp eval_subs_opts(subs, cwd, sources) do
    {subs, sources} =
      Enum.flat_map_reduce(subs, sources, fn sub, sources ->
        cwd = Path.expand(sub, cwd)
        {Path.wildcard(cwd), [Path.join(cwd, ".formatter.exs") | sources]}
      end)

    Enum.flat_map_reduce(subs, sources, fn sub, sources ->
      sub_formatter = Path.join(sub, ".formatter.exs")

      if File.exists?(sub_formatter) do
        formatter_opts = eval_file_with_keyword_list(sub_formatter)

        {formatter_opts_and_subs, sources} =
          eval_deps_and_subdirectories(sub, :in_memory, formatter_opts, sources)

        {[{sub, formatter_opts_and_subs}], sources}
      else
        {[], sources}
      end
    end)
  end

  defp assert_valid_dep_and_fetch_path(dep, deps_paths) when is_atom(dep) do
    with %{^dep => path} <- deps_paths,
         true <- File.dir?(path) do
      path
    else
      _ ->
        Mix.raise(
          "Unknown dependency #{inspect(dep)} given to :import_deps in the formatter configuration. " <>
            "Make sure the dependency is listed in your mix.exs for environment #{inspect(Mix.env())} " <>
            "and you have run \"mix deps.get\""
        )
    end
  end

  defp assert_valid_dep_and_fetch_path(dep, _deps_paths) do
    Mix.raise("Dependencies in :import_deps should be atoms, got: #{inspect(dep)}")
  end

  defp eval_file_with_keyword_list(path) do
    {opts, _} = Code.eval_file(path)

    unless Keyword.keyword?(opts) do
      Mix.raise("Expected #{inspect(path)} to return a keyword list, got: #{inspect(opts)}")
    end

    opts
  end

  defp expand_args([], cwd, dot_formatter, formatter_opts_and_subs, _opts) do
    if no_entries_in_formatter_opts?(formatter_opts_and_subs) do
      Mix.raise(
        "Expected one or more files/patterns to be given to mix format " <>
          "or for a .formatter.exs file to exist with an :inputs or :subdirectories key"
      )
    end

    dot_formatter
    |> expand_dot_inputs(cwd, formatter_opts_and_subs, %{})
    |> Enum.map(fn {file, {_dot_formatter, formatter_opts}} ->
      {file, find_formatter_for_file(file, formatter_opts)}
    end)
  end

  defp expand_args(files_and_patterns, cwd, _dot_formatter, {formatter_opts, subs}, opts) do
    files =
      for file_or_pattern <- files_and_patterns,
          file <- stdin_or_wildcard(file_or_pattern),
          uniq: true,
          do: file

    if files == [] do
      Mix.raise(
        "Could not find a file to format. The files/patterns given to command line " <>
          "did not point to any existing file. Got: #{inspect(files_and_patterns)}"
      )
    end

    for file <- files do
      if file == :stdin do
        stdin_filename = Path.expand(Keyword.get(opts, :stdin_filename, "stdin.exs"), cwd)

        {formatter, _opts} =
          find_formatter_and_opts_for_file(stdin_filename, {formatter_opts, subs})

        {file, formatter}
      else
        {formatter, _opts} = find_formatter_and_opts_for_file(file, {formatter_opts, subs})
        {file, formatter}
      end
    end
  end

  defp expand_dot_inputs(dot_formatter, cwd, {formatter_opts, subs}, acc) do
    if no_entries_in_formatter_opts?({formatter_opts, subs}) do
      Mix.raise("Expected :inputs or :subdirectories key in #{dot_formatter}")
    end

    map =
      for input <- List.wrap(formatter_opts[:inputs]),
          file <- Path.wildcard(Path.expand(input, cwd), match_dot: true),
          do: {file, {dot_formatter, formatter_opts}},
          into: %{}

    acc =
      Map.merge(acc, map, fn file, {dot_formatter1, _}, {dot_formatter2, formatter_opts} ->
        Mix.shell().error(
          "Both #{dot_formatter1} and #{dot_formatter2} specify the file #{file} in their " <>
            ":inputs option. To resolve the conflict, the configuration in #{dot_formatter1} " <>
            "will be ignored. Please change the list of :inputs in one of the formatter files " <>
            "so only one of them matches #{file}"
        )

        {dot_formatter2, formatter_opts}
      end)

    Enum.reduce(subs, acc, fn {sub, formatter_opts_and_subs}, acc ->
      sub_formatter = Path.join(sub, ".formatter.exs")
      expand_dot_inputs(sub_formatter, sub, formatter_opts_and_subs, acc)
    end)
  end

  defp find_formatter_for_file(file, formatter_opts) do
    ext = Path.extname(file)

    cond do
      plugins = find_plugins_for_extension(formatter_opts, ext) ->
        fn input ->
          Enum.reduce(plugins, input, fn plugin, input ->
            plugin.format(input, [extension: ext, file: file] ++ formatter_opts)
          end)
        end

      ext in ~w(.ex .exs) ->
        &elixir_format(&1, [file: file] ++ formatter_opts)

      true ->
        & &1
    end
  end

  defp find_plugins_for_extension(formatter_opts, ext) do
    plugins = Keyword.get(formatter_opts, :plugins, [])

    plugins =
      Enum.filter(plugins, fn plugin ->
        Code.ensure_loaded?(plugin) and function_exported?(plugin, :features, 1) and
          ext in List.wrap(plugin.features(formatter_opts)[:extensions])
      end)

    if plugins != [], do: plugins, else: nil
  end

  defp find_formatter_and_opts_for_file(file, formatter_opts_and_subs) do
    formatter_opts = recur_formatter_opts_for_file(file, formatter_opts_and_subs)
    {find_formatter_for_file(file, formatter_opts), formatter_opts}
  end

  defp recur_formatter_opts_for_file(file, {formatter_opts, subs}) do
    Enum.find_value(subs, formatter_opts, fn {sub, formatter_opts_and_subs} ->
      size = byte_size(sub)

      case file do
        <<prefix::binary-size(size), dir_separator, _::binary>>
        when prefix == sub and dir_separator in [?\\, ?/] ->
          recur_formatter_opts_for_file(file, formatter_opts_and_subs)

        _ ->
          nil
      end
    end)
  end

  defp no_entries_in_formatter_opts?({formatter_opts, subs}) do
    is_nil(formatter_opts[:inputs]) and subs == []
  end

  defp stdin_or_wildcard("-"), do: [:stdin]

  defp stdin_or_wildcard(path),
    do: path |> Path.expand() |> Path.wildcard(match_dot: true) |> Enum.filter(&File.regular?/1)

  defp elixir_format(content, formatter_opts) do
    case Code.format_string!(content, formatter_opts) do
      [] -> ""
      formatted_content -> IO.iodata_to_binary([formatted_content, ?\n])
    end
  end

  defp find_sigils_from_plugins(plugin, formatter_opts) do
    if Code.ensure_loaded?(plugin) and function_exported?(plugin, :features, 1) do
      List.wrap(plugin.features(formatter_opts)[:sigils])
    else
      []
    end
  end

  defp read_file(:stdin), do: IO.stream() |> Enum.to_list() |> IO.iodata_to_binary()
  defp read_file(file), do: File.read!(file)

  defp format_file({file, formatter}, task_opts) do
    input = read_file(file)
    output = formatter.(input)
    check_formatted? = Keyword.get(task_opts, :check_formatted, false)
    dry_run? = Keyword.get(task_opts, :dry_run, false)

    cond do
      check_formatted? ->
        if input == output, do: :ok, else: {:not_formatted, {file, input, output}}

      dry_run? ->
        :ok

      true ->
        write_or_print(file, input, output)
    end
  rescue
    exception ->
      {:exit, file, exception, __STACKTRACE__}
  end

  defp write_or_print(file, input, output) do
    cond do
      file == :stdin -> IO.write(output)
      input == output -> :ok
      true -> File.write!(file, output)
    end

    :ok
  end

  defp collect_status({:ok, :ok}, acc), do: acc

  defp collect_status({:ok, {:exit, _, _, _} = exit}, {exits, not_formatted}) do
    {[exit | exits], not_formatted}
  end

  defp collect_status({:ok, {:not_formatted, file}}, {exits, not_formatted}) do
    {exits, [file | not_formatted]}
  end

  defp check!({[], []}, _task_opts) do
    :ok
  end

  defp check!({[{:exit, :stdin, exception, stacktrace} | _], _not_formatted}, _task_opts) do
    Mix.shell().error("mix format failed for stdin")
    reraise exception, stacktrace
  end

  defp check!({[{:exit, file, exception, stacktrace} | _], _not_formatted}, _task_opts) do
    Mix.shell().error("mix format failed for file: #{Path.relative_to_cwd(file)}")
    reraise exception, stacktrace
  end

  defp check!({_exits, [_ | _] = not_formatted}, task_opts) do
    no_exit? = Keyword.get(task_opts, :no_exit, false)

    message = """
    The following files are not formatted:

    #{to_diffs(not_formatted)}
    """

    if no_exit? do
      Mix.shell().info(message)
    else
      Mix.raise("""
      mix format failed due to --check-formatted.
      #{message}
      """)
    end
  end

  defp to_diffs(files) do
    Enum.map_intersperse(files, "\n", fn
      {:stdin, unformatted, formatted} ->
        [IO.ANSI.reset(), text_diff_format(unformatted, formatted)]

      {file, unformatted, formatted} ->
        [
          IO.ANSI.bright(),
          IO.ANSI.red(),
          file,
          "\n",
          IO.ANSI.reset(),
          "\n",
          text_diff_format(unformatted, formatted)
        ]
    end)
  end

  @doc false
  @spec text_diff_format(String.t(), String.t()) :: iolist()
  def text_diff_format(old, new, opts \\ [])

  def text_diff_format(code, code, _opts), do: []

  def text_diff_format(old, new, opts) do
    opts = Keyword.validate!(opts, after: 2, before: 2, color: IO.ANSI.enabled?(), line: 1)
    crs? = String.contains?(old, "\r") || String.contains?(new, "\r")

    old = String.split(old, "\n")
    new = String.split(new, "\n")

    max = max(length(new), length(old))
    line_num_digits = max |> Integer.digits() |> length()
    opts = Keyword.put(opts, :line_num_digits, line_num_digits)

    {line, opts} = Keyword.pop!(opts, :line)

    old
    |> List.myers_difference(new)
    |> insert_cr_symbols(crs?)
    |> diff_to_iodata({line, line}, opts)
  end

  defp diff_to_iodata(diff, line_nums, opts, iodata \\ [])

  defp diff_to_iodata([], _line_nums, _opts, iodata), do: Enum.reverse(iodata)

  defp diff_to_iodata([{:eq, [""]}], _line_nums, _opts, iodata), do: Enum.reverse(iodata)

  defp diff_to_iodata([{:eq, lines}], line_nums, opts, iodata) do
    lines_after = Enum.take(lines, opts[:after])
    iodata = lines(iodata, {:eq, lines_after}, line_nums, opts)

    iodata =
      if length(lines) > opts[:after] do
        lines(iodata, :skip, opts)
      else
        iodata
      end

    Enum.reverse(iodata)
  end

  defp diff_to_iodata([{:eq, lines} | diff], {line, line}, opts, [] = iodata) do
    {start, lines_before} = Enum.split(lines, opts[:before] * -1)

    iodata =
      if length(lines) > opts[:before] do
        lines(iodata, :skip, opts)
      else
        iodata
      end

    line = line + length(start)
    iodata = lines(iodata, {:eq, lines_before}, {line, line}, opts)

    line = line + length(lines_before)
    diff_to_iodata(diff, {line, line}, opts, iodata)
  end

  defp diff_to_iodata([{:eq, lines} | diff], line_nums, opts, iodata) do
    if length(lines) > opts[:after] + opts[:before] do
      {lines1, lines2, lines3} = split(lines, opts[:after], opts[:before] * -1)

      iodata =
        iodata
        |> lines({:eq, lines1}, line_nums, opts)
        |> lines(:skip, opts)
        |> lines({:eq, lines3}, add_line_nums(line_nums, length(lines1) + length(lines2)), opts)

      line_nums = add_line_nums(line_nums, length(lines))

      diff_to_iodata(diff, line_nums, opts, iodata)
    else
      iodata = lines(iodata, {:eq, lines}, line_nums, opts)
      line_nums = add_line_nums(line_nums, length(lines))

      diff_to_iodata(diff, line_nums, opts, iodata)
    end
  end

  defp diff_to_iodata([{:del, [del]}, {:ins, [ins]} | diff], line_nums, opts, iodata) do
    iodata = lines(iodata, {:chg, del, ins}, line_nums, opts)
    diff_to_iodata(diff, add_line_nums(line_nums, 1), opts, iodata)
  end

  defp diff_to_iodata([{kind, lines} | diff], line_nums, opts, iodata) do
    iodata = lines(iodata, {kind, lines}, line_nums, opts)
    line_nums = add_line_nums(line_nums, length(lines), kind)

    diff_to_iodata(diff, line_nums, opts, iodata)
  end

  defp split(list, count1, count2) do
    {split1, split2} = Enum.split(list, count1)
    {split2, split3} = Enum.split(split2, count2)
    {split1, split2, split3}
  end

  defp lines(iodata, :skip, opts) do
    line_num = String.duplicate(@blank, opts[:line_num_digits] * 2 + 1)
    [[line_num, @gutter[:skip], @separator, @newline] | iodata]
  end

  defp lines(iodata, {:chg, del, ins}, line_nums, opts) do
    {del, ins} = line_diff(del, ins, opts)

    [
      [gutter(line_nums, :ins, opts), ins, @newline],
      [gutter(line_nums, :del, opts), del, @newline]
      | iodata
    ]
  end

  defp lines(iodata, {kind, lines}, line_nums, opts) do
    lines
    |> Enum.with_index()
    |> Enum.reduce(iodata, fn {line, offset}, iodata ->
      line_nums = add_line_nums(line_nums, offset, kind)
      [[gutter(line_nums, kind, opts), colorize(line, kind, false, opts), @newline] | iodata]
    end)
  end

  defp gutter(line_nums, kind, opts) do
    [line_num(line_nums, kind, opts), colorize(@gutter[kind], kind, false, opts), @separator]
  end

  defp line_num({line_num_old, line_num_new}, :eq, opts) do
    old =
      line_num_old
      |> to_string()
      |> String.pad_leading(opts[:line_num_digits], @line_num_pad)

    new =
      line_num_new
      |> to_string()
      |> String.pad_leading(opts[:line_num_digits], @line_num_pad)

    [old, @blank, new]
  end

  defp line_num({line_num_old, _line_num_new}, :del, opts) do
    old =
      line_num_old
      |> to_string()
      |> String.pad_leading(opts[:line_num_digits], @line_num_pad)

    new = String.duplicate(@blank, opts[:line_num_digits])
    [old, @blank, new]
  end

  defp line_num({_line_num_old, line_num_new}, :ins, opts) do
    old = String.duplicate(@blank, opts[:line_num_digits])

    new =
      line_num_new
      |> to_string()
      |> String.pad_leading(opts[:line_num_digits], @line_num_pad)

    [old, @blank, new]
  end

  defp line_diff(del, ins, opts) do
    diff = String.myers_difference(del, ins)

    Enum.reduce(diff, {[], []}, fn
      {:eq, str}, {del, ins} -> {[del | str], [ins | str]}
      {:del, str}, {del, ins} -> {[del | colorize(str, :del, true, opts)], ins}
      {:ins, str}, {del, ins} -> {del, [ins | colorize(str, :ins, true, opts)]}
    end)
  end

  defp colorize(str, kind, space?, opts) do
    if Keyword.fetch!(opts, :color) && Keyword.has_key?(@colors, kind) do
      color = Keyword.fetch!(@colors, kind)

      if space? do
        str
        |> String.split(~r/[\t\s]+/, include_captures: true)
        |> Enum.map(fn
          <<start::binary-size(1), _::binary>> = str when start in ["\t", "\s"] ->
            IO.ANSI.format([color[:space], str])

          str ->
            IO.ANSI.format([color[:text], str])
        end)
      else
        IO.ANSI.format([color[:text], str])
      end
    else
      str
    end
  end

  defp add_line_nums({line_num_old, line_num_new}, lines, kind \\ :eq) do
    case kind do
      :eq -> {line_num_old + lines, line_num_new + lines}
      :ins -> {line_num_old, line_num_new + lines}
      :del -> {line_num_old + lines, line_num_new}
    end
  end

  defp insert_cr_symbols(diffs, false), do: diffs
  defp insert_cr_symbols(diffs, true), do: do_insert_cr_symbols(diffs, [])

  defp do_insert_cr_symbols([], acc), do: Enum.reverse(acc)

  defp do_insert_cr_symbols([{:del, del}, {:ins, ins} | rest], acc) do
    {del, ins} = do_insert_cr_symbols(del, ins, {[], []})
    do_insert_cr_symbols(rest, [{:ins, ins}, {:del, del} | acc])
  end

  defp do_insert_cr_symbols([diff | rest], acc) do
    do_insert_cr_symbols(rest, [diff | acc])
  end

  defp do_insert_cr_symbols([left | left_rest], [right | right_rest], {left_acc, right_acc}) do
    {left, right} = insert_cr_symbol(left, right)
    do_insert_cr_symbols(left_rest, right_rest, {[left | left_acc], [right | right_acc]})
  end

  defp do_insert_cr_symbols([], right, {left_acc, right_acc}) do
    left = Enum.reverse(left_acc)
    right = Enum.reverse(right_acc, right)
    {left, right}
  end

  defp do_insert_cr_symbols(left, [], {left_acc, right_acc}) do
    left = Enum.reverse(left_acc, left)
    right = Enum.reverse(right_acc)
    {left, right}
  end

  defp insert_cr_symbol(left, right) do
    case {String.ends_with?(left, "\r"), String.ends_with?(right, "\r")} do
      {bool, bool} -> {left, right}
      {true, false} -> {String.replace(left, "\r", @cr), right}
      {false, true} -> {left, String.replace(right, "\r", @cr)}
    end
  end
end

defmodule :_next_ls_private_compiler_worker do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  def init(_arg) do
    working_dir = File.cwd!()
    {:ok, %{working_dir: working_dir}}
  end

  def enqueue_compiler(opts) do
    GenServer.cast(__MODULE__, {:compile, opts})
  end

  defp flush(acc) do
    receive do
      {:"$gen_cast", {:compile, opts}} -> flush([opts | acc])
    after
      0 -> acc
    end
  end

  @impl GenServer
  def handle_cast({:compile, opts}, state) do
    # we essentially compile now and rollup any newer requests to compile, so that we aren't doing 5 compiles
    # if we the user saves 5 times after saving one time
    newer_opts = flush([])
    from = Keyword.fetch!(opts, :from)
    caller_ref = Keyword.fetch!(opts, :caller_ref)

    for opt <- newer_opts do
      Process.send(opt[:from], {:compiler_canceled, opt[:caller_ref]}, [])
    end

    File.cd!(state.working_dir)

    if opts[:force] do
      File.rm_rf!(Path.join(opts[:working_dir], ".elixir-tools/_build"))
    end

    result = :_next_ls_private_compiler.compile()

    Process.send(from, {:compiler_result, caller_ref, result}, [])
    {:noreply, state}
  end
end

defmodule :_next_ls_private_compiler do
  @moduledoc false

  def start do
    children = [
      :_next_ls_private_compiler_worker
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: :_next_ls_private_application_supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)
    Process.unlink(pid)
    {:ok, pid}
  end

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

    Mix.Task.rerun("compile", [
      "--ignore-module-conflict",
      "--no-protocol-consolidation",
      "--return-errors"
    ])
  rescue
    e -> {:error, e}
  end
end
