defmodule NextLS.Autocomplete do
  # Based on `IEx.Autocomplete` from github.com/elixir-lang/elixir from 10/17/2023
  @moduledoc false

  require NextLS.Runtime

  @bitstring_modifiers [
    %{kind: :variable, name: "big"},
    %{kind: :variable, name: "binary"},
    %{kind: :variable, name: "bitstring"},
    %{kind: :variable, name: "integer"},
    %{kind: :variable, name: "float"},
    %{kind: :variable, name: "little"},
    %{kind: :variable, name: "native"},
    %{kind: :variable, name: "signed"},
    %{kind: :function, name: "size", arity: 1, docs: nil},
    %{kind: :function, name: "unit", arity: 1, docs: nil},
    %{kind: :variable, name: "unsigned"},
    %{kind: :variable, name: "utf8"},
    %{kind: :variable, name: "utf16"},
    %{kind: :variable, name: "utf32"}
  ]

  @alias_only_atoms ~w(alias import require)a
  @alias_only_charlists ~w(alias import require)c

  def expand(code, runtime) do
    case path_fragment(code) do
      [] -> expand_code(code, runtime)
      path -> expand_path(path)
    end
  end

  defp expand_code(code, runtime) do
    code = Enum.reverse(code)
    # helper = get_helper(code)

    case Code.Fragment.cursor_context(code) do
      {:alias, alias} ->
        expand_aliases(List.to_string(alias), runtime)

      {:unquoted_atom, unquoted_atom} ->
        expand_erlang_modules(List.to_string(unquoted_atom), runtime)

      # expansion when helper == ?b ->
      #   expand_typespecs(expansion, runtime, &get_module_callbacks(&1, runtime))

      # expansion when helper == ?t ->
      #   expand_typespecs(expansion, runtime, &get_module_types(&1, runtime))

      {:dot, path, hint} ->
        if alias = alias_only(path, hint, code, runtime) do
          expand_aliases(List.to_string(alias), runtime)
        else
          expand_dot(path, List.to_string(hint), false, runtime)
        end

      {:dot_arity, path, hint} ->
        expand_dot(path, List.to_string(hint), true, runtime)

      {:dot_call, path, hint} ->
        expand_dot_call(path, List.to_atom(hint), runtime)

      :expr ->
        expand_container_context(code, :expr, "", runtime) || expand_local_or_var("", "", runtime)

      {:local_or_var, local_or_var} ->
        hint = List.to_string(local_or_var)

        expand_container_context(code, :expr, hint, runtime) ||
          expand_local_or_var(hint, List.to_string(local_or_var), runtime)

      {:local_arity, local} ->
        expand_local(List.to_string(local), true, runtime)

      {:local_call, local} when local in @alias_only_charlists ->
        expand_aliases("", runtime)

      {:local_call, local} ->
        expand_local_call(List.to_atom(local), runtime)

      {:operator, operator} when operator in ~w(:: -)c ->
        expand_container_context(code, :operator, "", runtime) ||
          expand_local(List.to_string(operator), false, runtime)

      {:operator, operator} ->
        expand_local(List.to_string(operator), false, runtime)

      {:operator_arity, operator} ->
        expand_local(List.to_string(operator), true, runtime)

      {:operator_call, operator} when operator in ~w(|)c ->
        expand_container_context(code, :expr, "", runtime) || expand_local_or_var("", "", runtime)

      {:operator_call, _operator} ->
        expand_local_or_var("", "", runtime)

      {:sigil, []} ->
        expand_sigil(runtime)

      {:sigil, [_]} ->
        {:yes, [], ~w|" """ ' ''' \( / < [ { \||c}

      {:struct, struct} when is_list(struct) ->
        expand_structs(List.to_string(struct), runtime)

      {:struct, {:dot, {:alias, struct}, ~c""}} when is_list(struct) ->
        expand_structs(List.to_string(struct ++ ~c"."), runtime)

      # {:module_attribute, charlist}
      # :none
      _ ->
        no()
    end
  end

  # defp get_helper(expr) do
  #   with [helper | rest] when helper in ~c"bt" <- expr,
  #        [space_or_paren, char | _] <- squeeze_spaces(rest),
  #        true <-
  #          space_or_paren in ~c" (" and
  #            (char in ?A..?Z or char in ?a..?z or char in ?0..?9 or char in ~c"_:") do
  #     helper
  #   else
  #     _ -> nil
  #   end
  # end

  # defp squeeze_spaces(~c"  " ++ rest), do: squeeze_spaces([?\s | rest])
  # defp squeeze_spaces(rest), do: rest

  @doc false
  def exports(mod, runtime) do
    {:ok, exported?} =
      NextLS.Runtime.execute(runtime, do: Kernel.function_exported?(mod, :__info__, 1))

    if ensure_loaded?(mod, runtime) and exported? do
      NextLS.Runtime.execute!(runtime, do: mod.__info__(:macros)) ++
        (NextLS.Runtime.execute!(runtime, do: mod.__info__(:functions)) -- [__info__: 1])
    else
      NextLS.Runtime.execute!(runtime, do: mod.module_info(:exports)) -- [module_info: 0, module_info: 1]
    end
  end

  ## Typespecs

  # defp expand_typespecs({:dot, path, hint}, runtime, fun) do
  #   hint = List.to_string(hint)

  #   case expand_dot_path(path, runtime) do
  #     {:ok, mod} when is_atom(mod) ->
  #       mod
  #       |> fun.()
  #       |> then(&match_module_funs(runtime, mod, &1, hint, false))
  #       |> format_expansion(hint)

  #     _ ->
  #       no()
  #   end
  # end

  # defp expand_typespecs(_, _, _), do: no()

  ## Expand call

  defp expand_local_call(fun, runtime) do
    runtime
    |> imports_from_env()
    |> Enum.filter(fn {_, funs} -> List.keymember?(funs, fun, 0) end)
    |> Enum.flat_map(fn {module, _} -> get_signatures(fun, module) end)
    |> expand_signatures(runtime)
  end

  defp expand_dot_call(path, fun, runtime) do
    case expand_dot_path(path, runtime) do
      {:ok, mod} when is_atom(mod) -> fun |> get_signatures(mod) |> expand_signatures(runtime)
      _ -> no()
    end
  end

  defp get_signatures(name, module) when is_atom(module) do
    with docs when is_list(docs) <- get_docs(module, [:function, :macro], name) do
      Enum.map(docs, fn {_, _, signatures, _, _} -> Enum.join(signatures, " ") end)
    else
      _ -> []
    end
  end

  defp expand_signatures([_ | _] = signatures, _runtime) do
    [head | tail] = Enum.sort(signatures, &(String.length(&1) <= String.length(&2)))
    if tail != [], do: IO.write("\n" <> (tail |> Enum.reverse() |> Enum.join("\n")))
    yes([head])
  end

  defp expand_signatures([], runtime), do: expand_local_or_var("", "", runtime)

  ## Expand dot

  defp expand_dot(path, hint, exact?, runtime) do
    case expand_dot_path(path, runtime) do
      {:ok, mod} when is_atom(mod) and hint == "" -> expand_dot_aliases(mod, runtime)
      {:ok, mod} when is_atom(mod) -> expand_require(mod, hint, exact?, runtime)
      {:ok, map} when is_map(map) -> expand_map_field_access(map, hint)
      _ -> no()
    end
  end

  defp expand_dot_path({:unquoted_atom, var}, _runtime) do
    {:ok, List.to_atom(var)}
  end

  defp expand_dot_path(path, runtime) do
    case recur_expand_dot_path(path, runtime) do
      {:ok, [_ | _] = path} -> value_from_binding(Enum.reverse(path), runtime)
      other -> other
    end
  end

  defp recur_expand_dot_path({:var, var}, _runtime) do
    {:ok, [List.to_atom(var)]}
  end

  defp recur_expand_dot_path({:alias, var}, runtime) do
    {:ok, var |> List.to_string() |> String.split(".") |> value_from_alias(runtime)}
  end

  defp recur_expand_dot_path({:dot, parent, call}, runtime) do
    case recur_expand_dot_path(parent, runtime) do
      {:ok, [_ | _] = path} -> {:ok, [List.to_atom(call) | path]}
      _ -> :error
    end
  end

  defp recur_expand_dot_path(_, _runtime) do
    :error
  end

  defp expand_map_field_access(map, hint) do
    case match_map_fields(map, hint) do
      [%{kind: :map_key, name: ^hint, value_is_map: false}] -> no()
      map_fields when is_list(map_fields) -> format_expansion(map_fields)
    end
  end

  defp expand_dot_aliases(mod, runtime) do
    all =
      match_elixir_modules(mod, "", runtime) ++
        match_module_funs(runtime, mod, get_module_funs(mod, runtime), "", false)

    format_expansion(all)
  end

  defp expand_require(mod, hint, exact?, runtime) do
    mod
    |> get_module_funs(runtime)
    |> then(&match_module_funs(runtime, mod, &1, hint, exact?))
    |> format_expansion()
  end

  ## Expand local or var

  defp expand_local_or_var(code, hint, runtime) do
    format_expansion(match_var(code, hint, runtime) ++ match_local(code, false, runtime))
  end

  defp expand_local(hint, exact?, runtime) do
    format_expansion(match_local(hint, exact?, runtime))
  end

  defp expand_sigil(runtime) do
    sigils =
      "sigil_"
      |> match_local(false, runtime)
      |> Enum.map(fn %{name: "sigil_" <> rest} -> %{kind: :sigil, name: rest} end)

    format_expansion(match_local("~", false, runtime) ++ sigils)
  end

  defp match_local(hint, exact?, runtime) do
    imports = runtime |> imports_from_env() |> Enum.flat_map(&elem(&1, 1))
    module_funs = get_module_funs(Kernel.SpecialForms, runtime)

    match_module_funs(runtime, Kernel.SpecialForms, module_funs, hint, exact?) ++
      match_module_funs(runtime, nil, imports, hint, exact?)
  end

  defp match_var(code, hint, runtime) do
    code
    |> variables_from_binding(runtime)
    |> Enum.filter(&String.starts_with?(&1, hint))
    |> Enum.sort()
    |> Enum.map(&%{kind: :variable, name: &1})
  end

  ## Erlang modules

  defp expand_erlang_modules(hint, runtime) do
    format_expansion(match_erlang_modules(hint, runtime))
  end

  defp match_erlang_modules(hint, runtime) do
    for mod <- match_modules(hint, false, runtime), usable_as_unquoted_module?(mod) do
      %{kind: :module, name: mod}
    end
  end

  ## Structs

  defp expand_structs(hint, runtime) do
    aliases =
      for {alias, mod} <- aliases_from_env(runtime),
          [name] = Module.split(alias),
          String.starts_with?(name, hint),
          do: {mod, name}

    modules =
      for "Elixir." <> name = full_name <- match_modules("Elixir." <> hint, true, runtime),
          String.starts_with?(name, hint),
          mod = String.to_atom(full_name),
          do: {mod, name}

    all = aliases ++ modules

    {:ok, _} =
      NextLS.Runtime.execute(runtime, do: Code.ensure_all_loaded(Enum.map(all, &elem(&1, 0))))

    refs =
      for {mod, name} <- all,
          {:ok, is_struct} =
            NextLS.Runtime.execute(runtime, do: Kernel.function_exported?(mod, :__struct__, 1)),
          {:ok, is_exception} =
            NextLS.Runtime.execute(runtime, do: Kernel.function_exported?(mod, :exception, 1)),
          is_struct and not is_exception,
          do: %{kind: :struct, name: name}

    format_expansion(refs)
  end

  @dialyzer {:nowarn_function, expand_container_context: 4}
  defp expand_container_context(code, context, hint, runtime) do
    case container_context(code, runtime) do
      {:map, map, pairs} when context == :expr ->
        container_context_map_fields(pairs, map, hint)

      {:struct, alias, pairs} when context == :expr ->
        map = Map.from_struct(alias.__struct__)
        container_context_map_fields(pairs, map, hint)

      :bitstring_modifier ->
        existing =
          code
          |> List.to_string()
          |> String.split("::")
          |> List.last()
          |> String.split("-")

        @bitstring_modifiers
        |> Enum.filter(&(String.starts_with?(&1.name, hint) and &1.name not in existing))
        |> format_expansion()

      _ ->
        nil
    end
  end

  defp container_context_map_fields(pairs, map, hint) do
    pairs =
      Enum.reduce(pairs, map, fn {key, _}, map ->
        Map.delete(map, key)
      end)

    entries =
      for {key, _value} <- pairs,
          name = Atom.to_string(key),
          if(hint == "",
            do: not String.starts_with?(name, "_"),
            else: String.starts_with?(name, hint)
          ),
          do: %{kind: :keyword, name: name}

    format_expansion(entries)
  end

  defp container_context(code, runtime) do
    case Code.Fragment.container_cursor_to_quoted(code, columns: true) do
      {:ok, quoted} ->
        case Macro.path(quoted, &match?({:__cursor__, _, []}, &1)) do
          [cursor, {:%{}, _, pairs}, {:%, _, [{:__aliases__, _, aliases}, _map]} | _] ->
            container_context_struct(cursor, pairs, aliases, runtime)

          [
            cursor,
            pairs,
            {:|, _, _},
            {:%{}, _, _},
            {:%, _, [{:__aliases__, _, aliases}, _map]} | _
          ] ->
            container_context_struct(cursor, pairs, aliases, runtime)

          [cursor, pairs, {:|, _, [{variable, _, nil} | _]}, {:%{}, _, _} | _] ->
            container_context_map(cursor, pairs, variable, runtime)

          [cursor, {special_form, _, [cursor]} | _] when special_form in @alias_only_atoms ->
            :alias_only

          [cursor | tail] ->
            case remove_operators(tail, cursor) do
              [{:"::", _, [_, _]}, {:<<>>, _, [_ | _]} | _] -> :bitstring_modifier
              _ -> nil
            end

          _ ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp remove_operators([{op, _, [_, previous]} = head | tail], previous) when op in [:-],
    do: remove_operators(tail, head)

  defp remove_operators(tail, _previous), do: tail

  defp container_context_struct(cursor, pairs, aliases, runtime) do
    with {pairs, [^cursor]} <- Enum.split(pairs, -1),
         alias = value_from_alias(aliases, runtime),
         true <-
           Keyword.keyword?(pairs) and ensure_loaded?(alias, runtime) and
             function_exported?(alias, :__struct__, 1) do
      {:struct, alias, pairs}
    else
      _ -> nil
    end
  end

  @dialyzer {:nowarn_function, container_context_map: 4}
  defp container_context_map(cursor, pairs, variable, runtime) do
    with {pairs, [^cursor]} <- Enum.split(pairs, -1),
         {:ok, map} when is_map(map) <- value_from_binding([variable], runtime),
         true <- Keyword.keyword?(pairs) do
      {:map, map, pairs}
    else
      _ -> nil
    end
  end

  ## Aliases and modules

  defp alias_only(path, hint, code, runtime) do
    with {:alias, alias} <- path,
         [] <- hint,
         :alias_only <- container_context(code, runtime) do
      alias ++ [?.]
    else
      _ -> nil
    end
  end

  defp expand_aliases(all, runtime) do
    case String.split(all, ".") do
      [hint] ->
        all = match_aliases(hint, runtime) ++ match_elixir_modules(Elixir, hint, runtime)
        format_expansion(all)

      parts ->
        hint = List.last(parts)
        list = Enum.take(parts, length(parts) - 1)

        list
        |> value_from_alias(runtime)
        |> match_elixir_modules(hint, runtime)
        |> format_expansion()
    end
  end

  defp value_from_alias([name | rest], runtime) do
    case Keyword.fetch(aliases_from_env(runtime), Module.concat(Elixir, name)) do
      {:ok, name} when rest == [] -> name
      {:ok, name} -> Module.concat([name | rest])
      :error -> Module.concat([name | rest])
    end
  end

  defp match_aliases(hint, runtime) do
    for {alias, module} <- aliases_from_env(runtime),
        [name] = Module.split(alias),
        String.starts_with?(name, hint) do
      %{kind: :module, name: name, module: module}
    end
  end

  defp match_elixir_modules(module, hint, runtime) do
    name = Atom.to_string(module)
    depth = length(String.split(name, ".")) + 1
    base = name <> "." <> hint

    for mod <- match_modules(base, module == Elixir, runtime),
        parts = String.split(mod, "."),
        depth <= length(parts),
        name = Enum.at(parts, depth - 1),
        valid_alias_piece?("." <> name),
        uniq: true,
        do: %{kind: :module, name: name}
  end

  defp valid_alias_piece?(<<?., char, rest::binary>>) when char in ?A..?Z, do: valid_alias_rest?(rest)

  defp valid_alias_piece?(_), do: false

  defp valid_alias_rest?(<<char, rest::binary>>)
       when char in ?A..?Z
       when char in ?a..?z
       when char in ?0..?9
       when char == ?_,
       do: valid_alias_rest?(rest)

  defp valid_alias_rest?(<<>>), do: true
  defp valid_alias_rest?(rest), do: valid_alias_piece?(rest)

  ## Formatting

  defp format_expansion([]) do
    no()
  end

  defp format_expansion([uniq]) do
    yes([uniq])
  end

  defp format_expansion(entries) do
    yes(entries)
  end

  defp yes(entries) do
    {:yes, entries}
  end

  defp no do
    {:no, []}
  end

  ## Helpers

  defp usable_as_unquoted_module?(name) do
    # Conversion to atom is not a problem because
    # it is only called with existing modules names.
    Macro.classify_atom(String.to_atom(name)) in [:identifier, :unquoted]
  end

  defp match_modules(hint, elixir_root?, runtime) do
    elixir_root?
    |> get_modules(runtime)
    |> Enum.reject(fn mod ->
      Enum.any?(["Elixir.NextLSPrivate", "_next_ls_private_compiler"], fn prefix ->
        String.starts_with?(mod, prefix)
      end)
    end)
    |> Enum.sort()
    |> Enum.dedup()
    |> Enum.drop_while(&(not String.starts_with?(&1, hint)))
    |> Enum.take_while(&String.starts_with?(&1, hint))
  end

  defp get_modules(true, runtime) do
    ["Elixir.Elixir"] ++ get_modules(false, runtime)
  end

  defp get_modules(false, runtime) do
    {:ok, mods} =
      NextLS.Runtime.execute runtime do
        :code.all_loaded()
      end

    modules =
      Enum.map(mods, &Atom.to_string(elem(&1, 0)))

    {:ok, mode} = NextLS.Runtime.execute(runtime, do: :code.get_mode())

    case mode do
      :interactive -> modules ++ get_modules_from_applications(runtime)
      _otherwise -> modules
    end
  end

  defp get_modules_from_applications(runtime) do
    for [app] <- loaded_applications(runtime),
        {:ok, modules} =
          then(NextLS.Runtime.execute(runtime, do: :application.get_key(app, :modules)), fn {:ok, result} ->
            result
          end),
        module <- modules do
      Atom.to_string(module)
    end
  end

  defp loaded_applications(runtime) do
    # If we invoke :application.loaded_applications/0,
    # it can error if we don't call safe_fixtable before.
    # Since in both cases we are reaching over the
    # application controller internals, we choose to match
    # for performance.
    {:ok, apps} =
      NextLS.Runtime.execute runtime do
        :ets.match(:ac_tab, {{:loaded, :"$1"}, :_})
      end

    apps
  end

  defp match_module_funs(runtime, mod, funs, hint, exact?) do
    {content_type, fdocs} =
      case NextLS.Runtime.execute(runtime, do: Code.fetch_docs(mod)) do
        {:ok, {:docs_v1, _, _lang, content_type, _, _, fdocs}} ->
          {content_type, fdocs}

        _ ->
          {"text/markdown", []}
      end

    for_result =
      for {fun, arity} <- funs,
          name = Atom.to_string(fun),
          if(exact?, do: name == hint, else: String.starts_with?(name, hint)) do
        doc =
          Enum.find(fdocs, fn {{type, fname, _a}, _, _, _doc, _} ->
            type in [:function, :macro] and to_string(fname) == name
          end)

        doc =
          case doc do
            {_, _, _, %{"en" => fdoc}, _} ->
              """
              ## #{Macro.to_string(mod)}.#{name}/#{arity}

              #{NextLS.HoverHelpers.to_markdown(content_type, fdoc)}
              """

            _ ->
              nil
          end

        %{
          kind: :function,
          name: name,
          arity: arity,
          docs: doc
        }
      end

    Enum.sort_by(for_result, &{&1.name, &1.arity})
  end

  defp match_map_fields(map, hint) do
    for_result =
      for {key, value} when is_atom(key) <- Map.to_list(map),
          key = Atom.to_string(key),
          String.starts_with?(key, hint) do
        %{kind: :map_key, name: key, value_is_map: is_map(value)}
      end

    Enum.sort_by(for_result, & &1.name)
  end

  defp get_module_funs(mod, runtime) do
    cond do
      not ensure_loaded?(mod, runtime) ->
        []

      docs = get_docs(mod, [:function, :macro]) ->
        mod
        |> exports(runtime)
        |> Kernel.--(default_arg_functions_with_doc_false(docs))
        |> Enum.reject(&hidden_fun?(&1, docs))

      true ->
        exports(mod, runtime)
    end
  end

  # defp get_module_types(mod, runtime) do
  #   if ensure_loaded?(mod, runtime) do
  #     case Code.Typespec.fetch_types(mod) do
  #       {:ok, types} ->
  #         for {kind, {name, _, args}} <- types,
  #             kind in [:type, :opaque] do
  #           {name, length(args)}
  #         end

  #       :error ->
  #         []
  #     end
  #   else
  #     []
  #   end
  # end

  # defp get_module_callbacks(mod, runtime) do
  #   if ensure_loaded?(mod, runtime) do
  #     case Code.Typespec.fetch_callbacks(mod) do
  #       {:ok, callbacks} ->
  #         for {name_arity, _} <- callbacks do
  #           {_kind, name, arity} = IEx.Introspection.translate_callback_name_arity(name_arity)

  #           {name, arity}
  #         end

  #       :error ->
  #         []
  #     end
  #   else
  #     []
  #   end
  # end

  defp get_docs(mod, kinds, fun \\ nil) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, _, _, _, docs} ->
        if is_nil(fun) do
          for {{kind, _, _}, _, _, _, _} = doc <- docs, kind in kinds, do: doc
        else
          for {{kind, ^fun, _}, _, _, _, _} = doc <- docs, kind in kinds, do: doc
        end

      {:error, _} ->
        nil
    end
  end

  defp default_arg_functions_with_doc_false(docs) do
    for {{_, fun_name, arity}, _, _, :hidden, %{defaults: count}} <- docs,
        new_arity <- (arity - count)..arity,
        do: {fun_name, new_arity}
  end

  defp hidden_fun?({name, arity}, docs) do
    case Enum.find(docs, &match?({{_, ^name, ^arity}, _, _, _, _}, &1)) do
      nil -> hd(Atom.to_charlist(name)) == ?_
      {_, _, _, :hidden, _} -> true
      {_, _, _, _, _} -> false
    end
  end

  defp ensure_loaded?(Elixir, _runtime), do: false

  defp ensure_loaded?(mod, runtime) do
    {:ok, value} = NextLS.Runtime.execute(runtime, do: Code.ensure_loaded?(mod))
    value
  end

  ## Evaluator interface

  defp imports_from_env(_runtime) do
    # with {evaluator, server} <- IEx.Broker.evaluator(runtime),
    #      env_fields = IEx.Evaluator.fields_from_env(evaluator, server, [:functions, :macros]),
    #      %{functions: funs, macros: macros} <- env_fields do
    #   funs ++ macros
    # else
    #   _ -> []
    # end
    []
  end

  defp aliases_from_env(_runtime) do
    # with {evaluator, server} <- IEx.Broker.evaluator(runtime),
    #      %{aliases: aliases} <- IEx.Evaluator.fields_from_env(evaluator, server, [:aliases]) do
    #   aliases
    # else
    #   _ -> []
    # end
    []
  end

  defp variables_from_binding(_hint, _runtime) do
    # {:ok, ast} = Code.Fragment.container_cursor_to_quoted(hint, columns: true)

    # ast |> Macro.to_string() |> IO.puts()

    # NextLS.ASTHelpers.Variables.collect(ast)
    []
  end

  defp value_from_binding([_var | _path], _runtime) do
    # with {evaluator, server} <- IEx.Broker.evaluator(runtime) do
    #   IEx.Evaluator.value_from_binding(evaluator, server, var, path)
    # else
    #   _ -> :error
    # end
    []
  end

  ## Path helpers

  defp path_fragment(expr), do: path_fragment(expr, [])
  defp path_fragment([], _acc), do: []
  defp path_fragment([?{, ?# | _rest], _acc), do: []
  defp path_fragment([?", ?\\ | t], acc), do: path_fragment(t, [?\\, ?" | acc])

  defp path_fragment([?/, ?:, x, ?" | _], acc) when x in ?a..?z or x in ?A..?Z, do: [x, ?:, ?/ | acc]

  defp path_fragment([?/, ?., ?" | _], acc), do: [?., ?/ | acc]
  defp path_fragment([?/, ?" | _], acc), do: [?/ | acc]
  defp path_fragment([?" | _], _acc), do: []
  defp path_fragment([h | t], acc), do: path_fragment(t, [h | acc])

  defp expand_path(path) do
    path
    |> List.to_string()
    |> ls_prefix()
    |> Enum.map(fn path ->
      kind = if(File.dir?(path), do: :dir, else: :file)
      name = Path.basename(path)
      name = if(kind == :dir and not String.ends_with?(name, "/"), do: "#{name}/", else: name)

      %{kind: kind, name: name}
    end)
    |> format_expansion()
  end

  defp prefix_from_dir(".", <<c, _::binary>>) when c != ?., do: ""
  defp prefix_from_dir(dir, _fragment), do: dir

  defp ls_prefix(path) do
    dir = Path.dirname(path)
    prefix = prefix_from_dir(dir, path)

    case File.ls(dir) do
      {:ok, list} ->
        list
        |> Enum.map(&Path.join(prefix, &1))
        |> Enum.filter(&String.starts_with?(&1, path))

      _ ->
        []
    end
  end
end
