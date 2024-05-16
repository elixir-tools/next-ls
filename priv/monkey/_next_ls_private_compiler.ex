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
      File.rm_rf!(Path.join(opts[:working_dir], ".elixir-tools/_build2"))
    end

    result = :_next_ls_private_compiler.compile()

    Process.send(from, {:compiler_result, caller_ref, result}, [])
    {:noreply, state}
  end
end

defmodule :_next_ls_private_compiler do
  @moduledoc false

  def start do
    Code.put_compiler_option(:parser_options, columns: true, token_metadata: true)

    children = [
      :_next_ls_private_compiler_worker
    ]

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one, name: :_next_ls_private_application_supervisor)
    Process.unlink(pid)
    {:ok, pid}
  end

  @tracers Code.get_compiler_option(:tracers)

  def compile do
    # keep stdout on this node
    Process.group_leader(self(), Process.whereis(:user))

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

if Version.match?(System.version(), ">= 1.17.0-dev") do
  # vendored from github.com/elixir-tools/spitfire, to avoid any namespacing conflicts, and make 
  # it easier to load into the runtime node.
  # originally taken from https://gist.github.com/josevalim/3007fdbc5d56d79f15adedf7821620f3 and... expanded upon.
  defmodule :_next_ls_private_spitfire_env do
    @moduledoc false

    @env %{
      Macro.Env.prune_compile_info(__ENV__)
      | line: 0,
        file: "nofile",
        module: nil,
        function: nil,
        context_modules: []
    }
    defp env, do: @env

    @spec expand(Macro.t(), String.t()) :: {Macro.t(), map(), Macro.Env.t(), Macro.Env.t()}
    def expand(ast, file) do
      env = env()

      {ast, state, env} =
        expand(
          ast,
          %{functions: %{}, macros: %{}, attrs: []},
          %{env | file: file}
        )

      {cursor_state, cursor_env} =
        Process.get(:cursor_env, {Map.new(), env()})

      cursor_env =
        Map.merge(
          Map.from_struct(cursor_env),
          %{
            functions:
              Enum.filter(Map.get(state, :functions, []), fn {m, _} -> m == cursor_env.module end) ++
                cursor_env.functions,
            macros:
              Enum.filter(Map.get(state, :macros, []), fn {m, _} -> m == cursor_env.module end) ++ cursor_env.macros,
            attrs: Enum.uniq(Map.get(cursor_state, :attrs, [])),
            variables: for({name, nil} <- cursor_env.versioned_vars, do: name)
          }
        )

      {ast, state, env, cursor_env}
    end

    defp expand({:__cursor__, _meta, _} = node, state, env) do
      Process.put(:cursor_env, {state, env})
      {node, state, env}
    end

    defp expand({:@, _, [{:__cursor__, _, _}]} = node, state, env) do
      Process.put(:cursor_env, {state, env})
      {node, state, env}
    end

    defp expand([_ | _] = list, state, env) do
      expand_list(list, state, env)
    end

    defp expand({left, right}, state, env) do
      {left, state, env} = expand(left, state, env)
      {right, state, env} = expand(right, state, env)
      {{left, right}, state, env}
    end

    defp expand({:{}, meta, args}, state, env) do
      {args, state, env} = expand_list(args, state, env)
      {{:{}, meta, args}, state, env}
    end

    defp expand({:%{}, meta, args}, state, env) do
      {args, state, env} = expand_list(args, state, env)
      {{:%{}, meta, args}, state, env}
    end

    defp expand({:|, meta, [left, right]}, state, env) do
      {left, state, env} = expand(left, state, env)
      {right, state, env} = expand(right, state, env)
      {{:|, meta, [left, right]}, state, env}
    end

    defp expand({:<<>>, meta, args}, state, env) do
      {args, state, env} = expand_list(args, state, env)
      {{:<<>>, meta, args}, state, env}
    end

    ## __block__

    defp expand({:__block__, _, list}, state, env) do
      expand_list(list, state, env)
    end

    ## __aliases__

    defp expand({:__aliases__, meta, [head | tail] = list}, state, env) do
      case Macro.Env.expand_alias(env, meta, list, trace: false) do
        {:alias, alias} ->
          # A compiler may want to emit a :local_function trace in here.
          # Elixir also warns on easy to confuse aliases, such as True/False/Nil.
          {alias, state, env}

        :error ->
          {head, state, env} = expand(head, state, env)

          if is_atom(head) do
            # A compiler may want to emit a :local_function trace in here.
            {Module.concat([head | tail]), state, env}
          else
            {{:__aliases__, meta, [head | tail]}, state, env}
          end
      end
    end

    ## require, alias, import
    # Those are the main special forms and they require some care.
    #
    # First of all, if __aliases__ is changed to emit traces (which a
    # custom compiler should), we should not emit traces when expanding
    # the first argument of require/alias/import.
    #
    # Second, we must never expand the alias in `:as`. This is handled
    # below.
    #
    # Finally, multi-alias/import/require, such as alias Foo.Bar.{Baz, Bat}
    # is not implemented, check elixir_expand.erl on how to implement it.

    defp expand({form, meta, [arg]}, state, env) when form in [:require, :alias, :import] do
      expand({form, meta, [arg, []]}, state, env)
    end

    defp expand({:alias, meta, [arg, opts]} = node, state, env) do
      {arg, state, env} = expand(arg, state, env)
      {opts, state, env} = expand_directive_opts(opts, state, env)

      if is_atom(arg) do
        # An actual compiler would raise if the alias fails.
        case Macro.Env.define_alias(env, meta, arg, [trace: false] ++ opts) do
          {:ok, env} -> {arg, state, env}
          {:error, _} -> {arg, state, env}
        end
      else
        {node, state, env}
      end
    end

    defp expand({:require, meta, [arg, opts]} = node, state, env) do
      {arg, state, env} = expand(arg, state, env)
      {opts, state, env} = expand_directive_opts(opts, state, env)

      if is_atom(arg) do
        # An actual compiler would raise if the module is not defined or if the require fails.
        case Macro.Env.define_require(env, meta, arg, [trace: false] ++ opts) do
          {:ok, env} -> {arg, state, env}
          {:error, _} -> {arg, state, env}
        end
      else
        {node, state, env}
      end
    end

    defp expand({:import, meta, [arg, opts]} = node, state, env) do
      {arg, state, env} = expand(arg, state, env)
      {opts, state, env} = expand_directive_opts(opts, state, env)

      if is_atom(arg) do
        # An actual compiler would raise if the module is not defined or if the import fails.
        with true <- is_atom(arg) and Code.ensure_loaded?(arg),
             {:ok, env} <- Macro.Env.define_import(env, meta, arg, [trace: false] ++ opts) do
          {arg, state, env}
        else
          _ -> {arg, state, env}
        end
      else
        {node, state, env}
      end
    end

    ## =/2
    # We include = as an example of how we could handle variables.
    # For example, if you want to store where variables are defined,
    # you would collect this information in expand_pattern/3 and
    # invoke it from all relevant places (such as case, cond, try, etc).

    defp expand({match, meta, [left, right]}, state, env) when match in [:=, :<-] do
      {left, state, env} = expand_pattern(left, state, env)
      {right, state, env} = expand(right, state, env)
      {{match, meta, [left, right]}, state, env}
    end

    ## quote/1, quote/2
    # We need to expand options and look inside unquote/unquote_splicing.
    # A custom compiler may want to raise on this special form (for example),
    # quoted expressions make no sense if you are writing a language that
    # compiles to C.

    defp expand({:quote, _, [opts]}, state, env) do
      {block, opts} = Keyword.pop(opts, :do)
      {_opts, state, env} = expand_list(opts, state, env)
      expand_quote(block, state, env)
    end

    defp expand({:quote, _, [opts, block_opts]}, state, env) do
      {_opts, state, env} = expand_list(opts, state, env)
      expand_quote(Keyword.get(block_opts, :do), state, env)
    end

    ## Pin operator
    # It only appears inside match and it disables the match behaviour.

    defp expand({:^, meta, [arg]}, state, %{context: context} = env) do
      {arg, state, env} = expand(arg, state, %{env | context: nil})
      {{:^, meta, [arg]}, state, %{env | context: context}}
    end

    defp expand({:->, _, [params, block]}, state, env) do
      {_, state, penv} =
        for p <- params, reduce: {nil, state, env} do
          {_, state, penv} ->
            expand_pattern(p, state, penv)
        end

      {res, state, _env} = expand(block, state, penv)
      {res, state, env}
    end

    ## Remote call

    defp expand({{:., dot_meta, [module, fun]}, meta, args}, state, env) when is_atom(fun) and is_list(args) do
      {module, state, env} = expand(module, state, env)
      arity = length(args)

      if is_atom(module) do
        case Macro.Env.expand_require(env, meta, module, fun, arity,
               trace: false,
               check_deprecations: false
             ) do
          {:macro, module, callback} ->
            expand_macro(meta, module, fun, args, callback, state, env)

          :error ->
            expand_remote(meta, module, fun, args, state, env)
        end
      else
        {{{:., dot_meta, [module, fun]}, meta, args}, state, env}
      end
    end

    # self calling anonymous function

    defp expand({{:., _dmeta, [func]}, _callmeta, args}, state, env) when is_list(args) do
      {res, state, _env} = expand(func, state, env)
      {res, state, env}
    end

    defp expand({:in, meta, [left, right]}, state, %{context: :match} = env) do
      {left, state, env} = expand_pattern(left, state, env)
      {{:in, meta, [left, right]}, state, env}
    end

    ## Imported or local call

    defp expand({fun, meta, args}, state, env) when is_atom(fun) and is_list(args) do
      arity = length(args)

      # For language servers, we don't want to emit traces, nor expand local macros,
      # nor print deprecation warnings. Compilers likely want those set to true.
      case Macro.Env.expand_import(env, meta, fun, arity,
             trace: false,
             allow_locals: false,
             check_deprecations: false
           ) do
        {:macro, module, callback} ->
          expand_macro(meta, module, fun, args, callback, state, env)

        {:function, module, fun} ->
          expand_remote(meta, module, fun, args, state, env)

        :error ->
          expand_local(meta, fun, args, state, env)
      end
    end

    ## __MODULE__, __DIR__, __ENV__, __CALLER__
    # A custom compiler may want to raise.

    defp expand({:__MODULE__, _, ctx}, state, env) when is_atom(ctx) do
      {env.module, state, env}
    end

    defp expand({:__DIR__, _, ctx}, state, env) when is_atom(ctx) do
      {Path.dirname(env.file), state, env}
    end

    defp expand({:__ENV__, _, ctx}, state, env) when is_atom(ctx) do
      {Macro.escape(env), state, env}
    end

    defp expand({:__CALLER__, _, ctx} = ast, state, env) when is_atom(ctx) do
      {ast, state, env}
    end

    ## var
    # For the language server, we only want to capture definitions,
    # we don't care when they are used.

    defp expand({var, meta, ctx} = ast, state, %{context: :match} = env) when is_atom(var) and is_atom(ctx) do
      ctx = Keyword.get(meta, :context, ctx)
      vv = Map.update(env.versioned_vars, var, ctx, fn _ -> ctx end)

      {ast, state, %{env | versioned_vars: vv}}
    end

    ## Fallback

    defp expand(ast, state, env) do
      {ast, state, env}
    end

    ## Macro handling

    # This is going to be the function where you will intercept expansions
    # and attach custom behaviour. As an example, we will capture the module
    # definition, fully replacing the actual implementation. You could also
    # use this to capture module attributes (optionally delegating to the actual
    # implementation), function expansion, and more.
    defp expand_macro(_meta, Kernel, :defmodule, [alias, [{_, block}]], _callback, state, env) do
      {expanded, state, env} = expand(alias, state, env)

      if is_atom(expanded) do
        {full, env} = alias_defmodule(alias, expanded, env)
        env = %{env | context_modules: [full | env.context_modules]}

        # The env inside the block is discarded.
        {result, state, _env} = expand(block, state, %{env | module: full})
        {result, state, env}
      else
        # If we don't know the module name, do we still want to expand it here?
        # Perhaps it would be useful for dealing with local functions anyway?
        # But note that __MODULE__ will return nil.
        #
        # The env inside the block is discarded.
        {result, state, _env} = expand(block, state, env)
        {result, state, env}
      end
    end

    defp expand_macro(_meta, Kernel, type, args, _callback, state, env)
         when type in [:def, :defmacro, :defp, :defmacrop] do
      # extract the name, params, guards, and blocks
      {name, params, guards, blocks} =
        case args do
          [{:when, _, [{name, _, params} | guards]} | maybe_blocks] ->
            {name, params, guards, maybe_blocks}

          [{name, _, params} | maybe_blocks] ->
            {name, params, [], maybe_blocks}
        end

      blocks = List.first(blocks, [])

      # collect the environment from the parameters
      # parameters are always patterns
      {_, state, penv} =
        for p <- params, reduce: {nil, state, env} do
          {_, state, penv} ->
            expand_pattern(p, state, penv)
        end

      # expand guards, which includes the env from params
      {_, state, _} =
        for guard <- guards, reduce: {nil, state, penv} do
          {_, state, env} ->
            expand(guard, state, env)
        end

      # expand the blocks, there could be `:do`, `:after`, `:catch`, etc
      {blocks, state} =
        for {type, block} <- blocks, reduce: {[], state} do
          {acc, state} ->
            {res, state, _env} = expand(block, state, penv)
            {[{type, res} | acc], state}
        end

      arity = length(List.wrap(params))

      # determine which key to save this function in state
      state_key =
        case type do
          type when type in [:def, :defp] -> :functions
          type when type in [:defmacro, :defmacrop] -> :macros
        end

      funcs =
        if is_atom(name) do
          Map.update(state[state_key], env.module, [{name, arity}], &Keyword.put_new(&1, name, arity))
        else
          state[state_key]
        end

      {Enum.reverse(blocks), put_in(state[state_key], funcs), env}
    end

    defp expand_macro(meta, Kernel, :@, [{name, _, p}] = args, callback, state, env) when is_list(p) do
      state = update_in(state.attrs, &[to_string(name) | &1])
      expand_macro_callback(meta, Kernel, :@, args, callback, state, env)
    end

    defp expand_macro(meta, module, fun, args, callback, state, env) do
      expand_macro_callback(meta, module, fun, args, callback, state, env)
    end

    defp expand_macro_callback(meta, module, fun, args, callback, state, env) do
      callback.(meta, args)
    catch
      :throw, other ->
        throw(other)

      :error, _error ->
        {{{:., meta, [module, fun]}, meta, args}, state, env}
    else
      ast ->
        expand(ast, state, env)
    end

    ## defmodule helpers
    # defmodule automatically defines aliases, we need to mirror this feature here.

    # defmodule Elixir.Alias
    defp alias_defmodule({:__aliases__, _, [:"Elixir", _ | _]}, module, env), do: {module, env}

    # defmodule Alias in root
    defp alias_defmodule({:__aliases__, _, _}, module, %{module: nil} = env), do: {module, env}

    # defmodule Alias nested
    defp alias_defmodule({:__aliases__, meta, [h | t]}, _module, env) when is_atom(h) do
      module = Module.concat([env.module, h])
      alias = String.to_atom("Elixir." <> Atom.to_string(h))
      {:ok, env} = Macro.Env.define_alias(env, meta, module, as: alias, trace: false)

      case t do
        [] -> {module, env}
        _ -> {String.to_atom(Enum.join([module | t], ".")), env}
      end
    end

    # defmodule _
    defp alias_defmodule(_raw, module, env) do
      {module, env}
    end

    ## Helpers

    defp expand_remote(meta, module, fun, args, state, env) do
      # A compiler may want to emit a :remote_function trace in here.
      {args, state, env} = expand_list(args, state, env)
      {{{:., meta, [module, fun]}, meta, args}, state, env}
    end

    defp expand_local(_meta, fun, args, state, env) when fun in [:for, :with] do
      {params, blocks} =
        Enum.split_while(args, fn
          [{:do, _} | _] -> false
          _ -> true
        end)

      {_, state, penv} =
        for p <- params, reduce: {nil, state, env} do
          {_, state, penv} ->
            expand_pattern(p, state, penv)
        end

      {blocks, state} =
        for {type, block} <- List.first(blocks, []), reduce: {[], state} do
          {acc, state} ->
            env =
              if type == :do do
                penv
              else
                env
              end

            {res, state, env} = expand(block, state, env)
            {[{type, res} | acc], state}
        end

      {blocks, state, env}
    end

    defp expand_local(meta, fun, args, state, env) do
      # A compiler may want to emit a :local_function trace in here.
      {args, state, env} = expand_list(args, state, env)
      {{fun, meta, args}, state, env}
    end

    defp expand_pattern(pattern, state, %{context: context} = env) do
      {pattern, state, env} = expand(pattern, state, %{env | context: :match})
      {pattern, state, %{env | context: context}}
    end

    defp expand_directive_opts(opts, state, env) do
      opts =
        Keyword.replace_lazy(opts, :as, fn
          {:__aliases__, _, list} -> Module.concat(list)
          other -> other
        end)

      expand(opts, state, env)
    end

    defp expand_list(ast, state, env), do: expand_list(ast, state, env, [])

    defp expand_list([], state, env, acc) do
      {Enum.reverse(acc), state, env}
    end

    defp expand_list([h | t], state, env, acc) do
      {h, state, env} = expand(h, state, env)
      expand_list(t, state, env, [h | acc])
    end

    defp expand_quote(ast, state, env) do
      {_, {state, env}} =
        Macro.prewalk(ast, {state, env}, fn
          # We need to traverse inside unquotes
          {unquote, _, [expr]}, {state, env} when unquote in [:unquote, :unquote_splicing] ->
            {_expr, state, env} = expand(expr, state, env)
            {:ok, {state, env}}

          # If we find a quote inside a quote, we stop traversing it
          {:quote, _, [_]}, acc ->
            {:ok, acc}

          {:quote, _, [_, _]}, acc ->
            {:ok, acc}

          # Otherwise we go on
          node, acc ->
            {node, acc}
        end)

      {ast, state, env}
    end
  end
end
