defmodule NextLS.Autocomplete do
  # Based on `IEx.Autocomplete` from github.com/elixir-lang/elixir from 10/17/2023
  @moduledoc false

  require Logger
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
    %{kind: :function, name: "size", arity: 1},
    %{kind: :function, name: "unit", arity: 1},
    %{kind: :variable, name: "unsigned"},
    %{kind: :variable, name: "utf8"},
    %{kind: :variable, name: "utf16"},
    %{kind: :variable, name: "utf32"}
  ]

  @alias_only_atoms ~w(alias import require)a
  @alias_only_charlists ~w(alias import require)c

  def expand(code, runtime, env) do
    case path_fragment(code) do
      [] -> expand_code(code, runtime, env)
      path -> expand_path(path, runtime)
    end
  end

  defp expand_code(code, runtime, env) do
    code = Enum.reverse(code)
    # helper = get_helper(code)

    case Code.Fragment.cursor_context(code) do
      {:alias, alias} ->
        expand_aliases(List.to_string(alias), runtime, env)

      {:module_attribute, hint} ->
        match_attributes(List.to_string(hint), env)

      {:unquoted_atom, unquoted_atom} ->
        expand_erlang_modules(List.to_string(unquoted_atom), runtime)

      # expansion when helper == ?b ->
      #   expand_typespecs(expansion, runtime, &get_module_callbacks(&1, runtime))

      # expansion when helper == ?t ->
      #   expand_typespecs(expansion, runtime, &get_module_types(&1, runtime))

      {:dot, path, hint} ->
        if alias = alias_only(path, hint, code, runtime, env) do
          expand_aliases(List.to_string(alias), runtime, env)
        else
          expand_dot(path, List.to_string(hint), false, runtime, env)
        end

      {:dot_arity, path, hint} ->
        expand_dot(path, List.to_string(hint), true, runtime, env)

      {:dot_call, path, hint} ->
        expand_dot_call(path, List.to_atom(hint), runtime, env)

      :expr ->
        expand_container_context(code, :expr, "", runtime, env) || expand_local_or_var(code, "", runtime, env)

      {:local_or_var, local_or_var} ->
        hint = List.to_string(local_or_var)

        expand_container_context(code, :expr, hint, runtime, env) ||
          expand_local_or_var(hint, List.to_string(local_or_var), runtime, env)

      {:local_arity, local} ->
        expand_local(List.to_string(local), true, runtime, env)

      {:local_call, local} when local in @alias_only_charlists ->
        expand_aliases("", runtime, env)

      {:local_call, local} ->
        expand_local_call(List.to_atom(local), runtime, env)

      {:operator, operator} when operator in ~w(:: -)c ->
        expand_container_context(code, :operator, "", runtime, env) ||
          expand_local(List.to_string(operator), false, runtime, env)

      {:operator, operator} ->
        expand_local(List.to_string(operator), false, runtime, env)

      {:operator_arity, operator} ->
        expand_local(List.to_string(operator), true, runtime, env)

      {:operator_call, operator} when operator in ~w(|)c ->
        expand_container_context(code, :expr, "", runtime, env) || expand_local_or_var("", "", runtime, env)

      {:operator_call, _operator} ->
        expand_local_or_var("", "", runtime, env)

      {:sigil, []} ->
        expand_sigil(runtime, env)

      {:sigil, [_]} ->
        {:yes, [], ~w|" """ ' ''' \( / < [ { \||c}

      {:struct, struct} when is_list(struct) ->
        expand_structs(List.to_string(struct), runtime, env)

      {:struct, {:dot, {:alias, struct}, ~c""}} when is_list(struct) ->
        expand_structs(List.to_string(struct ++ ~c"."), runtime, env)

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

  defp expand_local_call(fun, _runtime, env) do
    env
    |> imports_from_env()
    |> Enum.filter(fn {_, funs} -> List.keymember?(funs, fun, 0) end)
    |> format_expansion()
  end

  defp expand_dot_call(path, fun, _runtime, env) do
    case expand_dot_path(path, env) do
      {:ok, mod} when is_atom(mod) -> format_expansion(fun)
      _ -> no()
    end
  end

  # defp get_signatures(name, module) when is_atom(module) do
  #   with docs when is_list(docs) <- get_docs(module, [:function, :macro], name) do
  #     Enum.map(docs, fn {_, _, signatures, _, _} -> Enum.join(signatures, " ") end)
  #   else
  #     _ -> []
  #   end
  # end

  # defp expand_signatures([_ | _] = signatures, _runtime) do
  #   [head | _tail] = Enum.sort(signatures, &(String.length(&1) <= String.length(&2)))
  #   # if tail != [], do: IO.write("\n" <> (tail |> Enum.reverse() |> Enum.join("\n")))
  #   yes([head])
  # end

  # defp expand_signatures([], runtime, env), do: expand_local_or_var("", "", runtime, env)

  ## Expand dot

  defp expand_dot(path, hint, exact?, runtime, env) do
    case expand_dot_path(path, env) do
      {:ok, mod} when is_atom(mod) and hint == "" -> expand_dot_aliases(mod, runtime)
      {:ok, mod} when is_atom(mod) -> expand_require(mod, hint, exact?, runtime)
      {:ok, map} when is_map(map) -> expand_map_field_access(map, hint)
      _ -> no()
    end
  end

  defp expand_dot_path({:unquoted_atom, var}, _env) do
    {:ok, List.to_atom(var)}
  end

  defp expand_dot_path(path, env) do
    case recur_expand_dot_path(path, env) do
      {:ok, [_ | _] = path} -> value_from_binding(Enum.reverse(path), env)
      other -> other
    end
  end

  defp recur_expand_dot_path({:var, var}, _env) do
    {:ok, [List.to_atom(var)]}
  end

  defp recur_expand_dot_path({:alias, var}, env) do
    {:ok, var |> List.to_string() |> String.split(".") |> value_from_alias(env)}
  end

  defp recur_expand_dot_path({:dot, parent, call}, env) do
    case recur_expand_dot_path(parent, env) do
      {:ok, [_ | _] = path} -> {:ok, [List.to_atom(call) | path]}
      _ -> :error
    end
  end

  defp recur_expand_dot_path(_, _env) do
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

  defp expand_local_or_var(code, hint, runtime, env) do
    format_expansion(match_var(code, hint, runtime, env) ++ match_local(hint, false, runtime, env))
  end

  defp expand_local(hint, exact?, runtime, env) do
    format_expansion(match_local(hint, exact?, runtime, env))
  end

  defp expand_sigil(runtime, env) do
    sigils =
      "sigil_"
      |> match_local(false, runtime, env)
      |> Enum.map(fn %{name: "sigil_" <> rest} -> %{kind: :sigil, name: rest} end)

    format_expansion(match_local("~", false, runtime, env) ++ sigils)
  end

  defp match_local(hint, exact?, runtime, env) do
    special_form_funs = get_module_funs(Kernel.SpecialForms, runtime)
    # kernel_funs = get_module_funs(Kernel, runtime)

    # match_module_funs(runtime, Kernel, kernel_funs, hint, exact?) ++
    match_module_funs(runtime, Kernel.SpecialForms, special_form_funs, hint, exact?) ++
      Enum.flat_map(imports_from_env(env), fn {mod, funs} ->
        match_module_funs(runtime, mod, funs, hint, exact?)
      end)
  end

  defp match_var(code, hint, _runtime, env) do
    code
    |> variables_from_binding(env)
    |> Enum.filter(&String.starts_with?(to_string(&1), hint))
    |> Enum.sort()
    |> Enum.map(&%{kind: :variable, name: &1})
  end

  ## Erlang modules

  defp expand_erlang_modules(hint, runtime) do
    format_expansion(match_erlang_modules(hint, runtime))
  end

  defp match_erlang_modules(hint, runtime) do
    for mod <- match_modules(hint, false, runtime), usable_as_unquoted_module?(mod) do
      %{
        kind: :module,
        name: mod,
        data: String.to_atom(mod)
      }
    end
  end

  ## Structs

  defp expand_structs(hint, runtime, env) do
    aliases =
      for {alias, mod} <- aliases_from_env(env),
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

  @dialyzer {:nowarn_function, expand_container_context: 5}
  defp expand_container_context(code, context, hint, runtime, env) do
    case container_context(code, runtime, env) do
      {:map, map, pairs} when context == :expr ->
        container_context_map_fields(pairs, map, hint)

      {:struct, alias, pairs} when context == :expr ->
        map = Map.from_struct(NextLS.Runtime.execute!(runtime, do: alias.__struct__))
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

  defp container_context(code, runtime, env) do
    case Code.Fragment.container_cursor_to_quoted(code, columns: true) do
      {:ok, quoted} ->
        case Macro.path(quoted, &match?({:__cursor__, _, []}, &1)) do
          [cursor, {:%{}, _, pairs}, {:%, _, [{:__aliases__, _, aliases}, _map]} | _] ->
            container_context_struct(cursor, pairs, aliases, runtime, env)

          [
            cursor,
            pairs,
            {:|, _, _},
            {:%{}, _, _},
            {:%, _, [{:__aliases__, _, aliases}, _map]} | _
          ] ->
            container_context_struct(cursor, pairs, aliases, runtime, env)

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

  defp container_context_struct(cursor, pairs, aliases, runtime, env) do
    with {pairs, [^cursor]} <- Enum.split(pairs, -1),
         alias = value_from_alias(aliases, env),
         true <-
           Keyword.keyword?(pairs) and ensure_loaded?(alias, runtime) and
             NextLS.Runtime.execute!(runtime, do: Kernel.function_exported?(alias, :__struct__, 1)) do
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

  defp alias_only(path, hint, code, runtime, env) do
    with {:alias, alias} <- path,
         [] <- hint,
         :alias_only <- container_context(code, runtime, env) do
      alias ++ [?.]
    else
      _ -> nil
    end
  end

  defp expand_aliases(all, runtime, env) do
    case String.split(all, ".") do
      [hint] ->
        all = match_aliases(hint, runtime, env) ++ match_elixir_modules(Elixir, hint, runtime)
        format_expansion(all)

      parts ->
        hint = List.last(parts)
        list = Enum.take(parts, length(parts) - 1)

        list
        |> value_from_alias(env)
        |> match_elixir_modules(hint, runtime)
        |> format_expansion()
    end
  end

  defp match_attributes(hint, env) do
    format_expansion(
      for attr <- env.attrs, String.starts_with?(attr, hint) do
        %{kind: :attribute, name: attr, docs: ""}
      end
    )
  end

  defp value_from_alias([name | rest], env) do
    case Keyword.fetch(aliases_from_env(env), Module.concat(Elixir, name)) do
      {:ok, name} when rest == [] -> name
      {:ok, name} -> Module.concat([name | rest])
      :error -> Module.concat([name | rest])
    end
  end

  defp match_aliases(hint, _runtime, env) do
    for {alias, module} <- aliases_from_env(env),
        [name] = Module.split(alias),
        String.starts_with?(name, hint) do
      # {content_type, mdoc} =
      #   case NextLS.Runtime.execute(runtime, do: Code.fetch_docs(module)) do
      #     {:ok, {:docs_v1, _, _lang, content_type, %{"en" => mdoc}, _, _fdocs}} ->
      #       {content_type, mdoc}

      #     _ ->
      #       {"text/markdown", nil}
      #   end

      %{
        kind: :module,
        name: name,
        data: module,
        module: module
        # docs: """
        ### #{Macro.to_string(module)}

        ## {NextLS.HoverHelpers.to_markdown(content_type, mdoc)}
        # """
      }
    end
  end

  defp match_elixir_modules(module, hint, runtime) do
    name = Atom.to_string(module)
    depth = length(String.split(name, ".")) + 1
    base = name <> "." <> hint

    for_result =
      for mod <- match_modules(base, module == Elixir, runtime),
          parts = String.split(mod, "."),
          depth <= length(parts),
          name = Enum.at(parts, depth - 1),
          valid_alias_piece?("." <> name) do
        alias = Module.concat([mod])

        # {content_type, mdoc} =
        #   case NextLS.Runtime.execute(runtime, do: Code.fetch_docs(alias)) do
        #     {:ok, {:docs_v1, _, _lang, content_type, %{"en" => mdoc}, _, _fdocs}} ->
        #       {content_type, mdoc}

        #     _ ->
        #       {"text/markdown", nil}
        #   end

        %{
          kind: :module,
          data: alias,
          name: name
          # docs: """
          ### #{Macro.to_string(alias)}

          ## {NextLS.HoverHelpers.to_markdown(content_type, mdoc)}
          # """
        }
      end

    Enum.uniq_by(for_result, & &1.name)
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
      Enum.any?(["Elixir.NextLSPrivate", "_next_ls_private"], fn prefix ->
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
    {ms, mods} =
      :timer.tc(
        fn ->
          {:ok, mods} =
            NextLS.Runtime.execute runtime do
              :code.all_loaded()
            end

          mods
        end,
        :millisecond
      )

    Logger.debug("load modules: #{ms}ms")

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

  defp match_module_funs(_runtime, mod, funs, hint, exact?) do
    # {content_type, fdocs} =
    #   case NextLS.Runtime.execute(runtime, do: Code.fetch_docs(mod)) do
    #     {:ok, {:docs_v1, _, _lang, content_type, _, _, fdocs}} ->
    #       {content_type, fdocs}

    #     _ ->
    #       {"text/markdown", []}
    #   end

    functions =
      for {fun, arity} <- funs,
          name = Atom.to_string(fun),
          if(exact?, do: name == hint, else: String.starts_with?(name, hint)) do
        # doc =
        #  Enum.find(fdocs, fn {{type, fname, _a}, _, _, _doc, _} ->
        #    type in [:function, :macro] and to_string(fname) == name
        #  end)

        # doc =
        #  case doc do
        #    {_, _, _, %{"en" => fdoc}, _} ->
        #      """
        #      ## #{Macro.to_string(mod)}.#{name}/#{arity}

        #      #{NextLS.HoverHelpers.to_markdown(content_type, fdoc)}
        #      """

        #    _ ->
        #      nil
        #  end

        %{
          kind: :function,
          data: {mod, name, arity},
          name: name,
          arity: arity
          # docs: doc
        }
      end

    Enum.sort_by(functions, &{&1.name, &1.arity})
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

  defp ensure_loaded?(Elixir, _runtime), do: false

  defp ensure_loaded?(mod, runtime) do
    {:ok, value} = NextLS.Runtime.execute(runtime, do: Code.ensure_loaded?(mod))
    value
  end

  ## Evaluator interface

  defp imports_from_env(env) do
    env.functions ++ env.macros
  end

  defp aliases_from_env(env) do
    env.aliases
  end

  defp variables_from_binding(_hint, env) do
    env.variables
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

  defp expand_path(path, runtime) do
    path
    |> List.to_string()
    |> ls_prefix(runtime)
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

  defp ls_prefix(path, runtime) do
    dir = Path.dirname(path)
    prefix = prefix_from_dir(dir, path)

    case NextLS.Runtime.execute!(runtime, do: File.ls(dir)) do
      {:ok, list} ->
        list
        |> Enum.map(&Path.join(prefix, &1))
        |> Enum.filter(&String.starts_with?(&1, path))

      _ ->
        []
    end
  end
end
