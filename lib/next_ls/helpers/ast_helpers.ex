defmodule NextLS.ASTHelpers do
  @moduledoc false

  defmodule Attributes do
    @moduledoc false
    @spec get_attribute_reference_name(String.t(), integer(), integer()) :: String.t() | nil
    def get_attribute_reference_name(file, line, column) do
      ast = ast_from_file(file)

      {_ast, name} =
        Macro.prewalk(ast, nil, fn
          {:@, [line: ^line, column: ^column], [{name, _meta, nil}]} = ast, _acc -> {ast, "@#{name}"}
          other, acc -> {other, acc}
        end)

      name
    end

    @spec get_module_attributes(String.t(), module()) :: [{atom(), String.t(), integer(), integer()}]
    def get_module_attributes(file, module) do
      reserved_attributes = Module.reserved_attributes()

      symbols = parse_symbols(file, module)

      Enum.filter(symbols, fn
        {:attribute, "@" <> name, _, _} ->
          not Map.has_key?(reserved_attributes, String.to_atom(name))

        _other ->
          false
      end)
    end

    defp parse_symbols(file, module) do
      ast = ast_from_file(file)

      {_ast, %{symbols: symbols}} =
        Macro.traverse(ast, %{modules: [], symbols: []}, &prewalk/2, &postwalk(&1, &2, module))

      symbols
    end

    # add module name to modules stack on enter
    defp prewalk({:defmodule, _, [{:__aliases__, _, module_name_atoms} | _]} = ast, acc) do
      modules = [module_name_atoms | acc.modules]
      {ast, %{acc | modules: modules}}
    end

    defp prewalk(ast, acc), do: {ast, acc}

    defp postwalk({:@, meta, [{name, _, args}]} = ast, acc, module) when is_list(args) do
      ast_module =
        acc.modules
        |> Enum.reverse()
        |> List.flatten()
        |> Module.concat()

      if module == ast_module do
        symbols = [{:attribute, "@#{name}", meta[:line], meta[:column]} | acc.symbols]
        {ast, %{acc | symbols: symbols}}
      else
        {ast, acc}
      end
    end

    # remove module name from modules stack on exit
    defp postwalk({:defmodule, _, [{:__aliases__, _, _modules} | _]} = ast, acc, _module) do
      [_exit_mudule | modules] = acc.modules
      {ast, %{acc | modules: modules}}
    end

    defp postwalk(ast, acc, _module), do: {ast, acc}

    defp ast_from_file(file) do
      file |> File.read!() |> Code.string_to_quoted!(columns: true)
    end
  end

  defmodule Aliases do
    @moduledoc """
    Responsible for extracting the relevant portion from a single or multi alias.

    ## Example

    ```elixir
    alias Foo.Bar.Baz
    #     ^^^^^^^^^^^

    alias Foo.Bar.{Baz, Bing}
    #              ^^^  ^^^^

    alias Foo.Bar.{
      Baz,
    # ^^^
      Bing
    # ^^^^
    }
    ```
    """

    def extract_alias_range(code, {start, stop}, ale) do
      lines =
        code
        |> String.split("\n")
        |> Enum.map(&String.split(&1, ""))
        |> Enum.slice((start.line - 1)..(stop.line - 1))

      code =
        if start.line == stop.line do
          [line] = lines

          line
          |> Enum.slice(start.col..stop.col)
          |> Enum.join()
        else
          [first | rest] = lines
          first = Enum.drop(first, start.col)

          [last | rest] = Enum.reverse(rest)

          length = Enum.count(last)
          last = Enum.drop(last, -(length - stop.col - 1))

          Enum.map_join([first | Enum.reverse([last | rest])], "\n", &Enum.join(&1, ""))
        end

      {_, range} =
        code
        |> Code.string_to_quoted!(columns: true, column: start.col, token_metadata: true)
        |> Macro.prewalk(nil, fn ast, range ->
          range =
            case ast do
              {:__aliases__, meta, aliases} ->
                if ale == List.last(aliases) do
                  {{meta[:line] + start.line - 1, meta[:column]},
                   {meta[:last][:line] + start.line - 1, meta[:last][:column] + String.length(to_string(ale)) - 1}}
                else
                  range
                end

              _ ->
                range
            end

          {ast, range}
        end)

      range
    end
  end

  defmodule Variables do
    @moduledoc false

    @scope_breaks ~w(defmodule defprotocol defimpl defdelegate fn if unless case cond for with receive try quote)a
    @defs_with_args ~w(def defp defmacro defmacrop)a
    @blocks ~w(do catch rescue after else)a
    @scope_ends [:->] ++ @scope_breaks ++ @defs_with_args

    @spec get_variable_definition(String.t(), {integer(), integer()}) :: {atom(), {Range.t(), Range.t()}} | nil
    def get_variable_definition(file, position) do
      file = File.read!(file)
      ast = Code.string_to_quoted!(file, columns: true)

      {_ast, %{vars: vars}} =
        Macro.traverse(
          ast,
          %{vars: [], symbols: %{}, sym_ranges: [], scope: []},
          &prewalk/2,
          &postwalk/2
        )

      Enum.find_value(vars, fn %{name: name, sym_range: range, ref_range: ref_range} ->
        if position_in_range?(position, ref_range), do: {name, range}, else: nil
      end)
    end

    @spec list_variable_references(String.t(), {integer(), integer()}) :: [{atom(), {Range.t(), Range.t()}}]
    def list_variable_references(file, position) do
      file = File.read!(file)
      ast = Code.string_to_quoted!(file, columns: true)

      {_ast, %{vars: vars}} =
        Macro.traverse(
          ast,
          %{vars: [], symbols: %{}, sym_ranges: [], scope: []},
          &prewalk/2,
          &postwalk/2
        )

      symbol =
        Enum.find_value(vars, fn %{name: name, sym_range: range, ref_range: ref_range} ->
          if position_in_range?(position, ref_range), do: {name, range}, else: nil
        end)

      position =
        case symbol do
          nil -> position
          {_, {line.._, column.._}} -> {line, column}
        end

      Enum.reduce(vars, [], fn val, acc ->
        if position_in_range?(position, val.sym_range) do
          [{val.name, val.ref_range} | acc]
        else
          acc
        end
      end)
    end

    # search symbols in function and macro definition args and increase scope
    defp prewalk({operation, meta, [args | _]} = ast, acc) when operation in @defs_with_args do
      acc = increase_scope_nesting(acc, meta[:line])
      acc = find_symbols(args, acc)
      {ast, acc}
    end

    # special case for 'cond', don't search for symbols in left side of 'cond' clause
    defp prewalk({:->, meta, _} = ast, %{scope: ["cond" <> _ | _]} = acc) do
      acc = increase_scope_nesting(acc, meta[:line])
      {ast, acc}
    end

    # search symbols in a left side of forward arrow clause adn increase scope
    defp prewalk({:->, meta, [left, _right]} = ast, acc) do
      acc = increase_scope_nesting(acc, meta[:line])
      acc = find_symbols(left, acc)
      {ast, acc}
    end

    # special case for 'cond'
    defp prewalk({:cond, meta, _args} = ast, acc) do
      acc = increase_scope_nesting(acc, "cond#{meta[:line]}")
      {ast, acc}
    end

    # increase scope on enter
    defp prewalk({operation, meta, _args} = ast, acc) when operation in @scope_breaks do
      acc = increase_scope_nesting(acc, meta[:line])
      {ast, acc}
    end

    # special case for 'cond'
    defp prewalk({:do, _args} = ast, %{scope: ["cond" <> _ | _]} = acc) do
      acc = increase_scope_nesting(acc, "conddo")
      {ast, acc}
    end

    # increase scope on enter 'do/end' block
    defp prewalk({operation, _args} = ast, acc) when operation in @blocks do
      acc = increase_scope_nesting(acc, operation)
      {ast, acc}
    end

    # search symbols inside left side of a match or <- and fix processig sequence
    defp prewalk({operation, meta, [left, right]}, acc) when operation in [:=, :<-, :destructure] do
      acc = find_symbols(left, acc)
      {{operation, meta, [right, left]}, acc}
    end

    # exclude attribute macro from variable search
    defp prewalk({:@, _, _}, acc) do
      {nil, acc}
    end

    # find variable
    defp prewalk({name, meta, nil} = ast, acc) do
      range = calculate_range(name, meta[:line], meta[:column])
      type = if range in acc.sym_ranges, do: :sym, else: :ref
      var = {type, name, range, acc.scope}

      acc = collect_var(acc, var)

      {ast, acc}
    end

    defp prewalk(ast, acc), do: {ast, acc}

    # decrease scope when exiting it
    defp postwalk({operation, _, _} = ast, acc) when operation in @scope_ends do
      acc = decrease_scope_nesting(acc)
      {ast, acc}
    end

    # decrease scope when exiting 'do/else' block
    defp postwalk({operation, _} = ast, acc) when operation in @blocks do
      acc = decrease_scope_nesting(acc)
      {ast, acc}
    end

    defp postwalk(ast, acc), do: {ast, acc}

    defp find_symbols(ast, acc) do
      {_ast, acc} = Macro.prewalk(ast, acc, &find_symbol/2)
      acc
    end

    defp find_symbol({operation, _, _}, acc) when operation in [:^, :unquote] do
      {nil, acc}
    end

    # exclude right side of 'when' from symbol search
    defp find_symbol({:when, _, [left, _right]}, acc) do
      {left, acc}
    end

    defp find_symbol({name, meta, nil} = ast, acc) do
      range = calculate_range(name, meta[:line], meta[:column])
      acc = Map.update!(acc, :sym_ranges, &[range | &1])
      {ast, acc}
    end

    defp find_symbol(ast, acc), do: {ast, acc}

    defp calculate_range(name, line, column) do
      length = name |> to_string() |> String.length()

      {line..line, column..(column + length)}
    end

    defp position_in_range?({position_line, position_column}, {range_lines, range_columns}) do
      position_line in range_lines and position_column in range_columns
    end

    defp in_scope?(inner_scope, outer_scope) do
      outer = Enum.reverse(outer_scope)
      inner = Enum.reverse(inner_scope)
      List.starts_with?(inner, outer)
    end

    defp increase_scope_nesting(acc, identifier) do
      Map.update!(acc, :scope, &[to_string(identifier) | &1])
    end

    defp decrease_scope_nesting(acc) do
      Map.update!(acc, :scope, &tl(&1))
    end

    # add new symbol with scope
    defp collect_var(acc, {:sym, name, range, scope}) do
      symbol = %{
        range: range,
        scope: scope
      }

      update_in(acc, [:symbols, name], fn
        nil -> [symbol]
        vals -> [symbol | vals]
      end)
    end

    # ignore reference which was not defined yet
    defp collect_var(%{symbols: symbols} = acc, {:ref, name, _, _}) when not is_map_key(symbols, name), do: acc

    # find symbol for current reference and save sym/ref pair
    # remove symbol scopes if reference is from outer scope
    defp collect_var(acc, {:ref, name, range, scope}) do
      case Enum.split_while(acc.symbols[name], &(not in_scope?(scope, &1.scope))) do
        {_, []} ->
          acc

        {_, symbols_in_scope} ->
          var_pair = %{
            name: name,
            sym_range: hd(symbols_in_scope).range,
            ref_range: range
          }

          acc
          |> Map.update!(:vars, &[var_pair | &1])
          |> Map.update!(:symbols, &%{&1 | name => symbols_in_scope})
      end
    end
  end
end
