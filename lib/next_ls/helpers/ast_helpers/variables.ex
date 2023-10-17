defmodule NextLS.ASTHelpers.Variables do
  @moduledoc false

  @scope_breaks ~w(defmodule defprotocol defimpl defdelegate fn if unless case cond for with receive try quote)a
  @defs_with_args ~w(def defp defmacro defmacrop)a
  @blocks ~w(do catch rescue after else)a
  @scope_ends [:->] ++ @scope_breaks ++ @defs_with_args

  @spec get_variable_definition(String.t(), {integer(), integer()}) :: {atom(), {Range.t(), Range.t()}} | nil
  def get_variable_definition(file, position) do
    file = File.read!(file)

    case Code.string_to_quoted(file, columns: true) do
      {:ok, ast} ->
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

      _error ->
        nil
    end
  end

  def collect(ast) do
    {_, %{cursor: cursor, symbols: symbols}} =
      ast
      |> Macro.traverse(%{vars: [], symbols: %{}, sym_ranges: [], scope: []}, &prewalk/2, &postwalk/2)

    cscope = Enum.reverse(cursor.scope)

    for {name, defs} <- symbols, def <- defs, List.starts_with?(cscope, Enum.reverse(def.scope)) do
      to_string(name)
    end
  end

  @spec list_variable_references(String.t(), {integer(), integer()}) :: [{atom(), {Range.t(), Range.t()}}]
  def list_variable_references(file, position) do
    file = File.read!(file)

    case Code.string_to_quoted(file, columns: true) do
      {:ok, ast} ->
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

      _error ->
        []
    end
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

  # search symbols in a left side of forward arrow clause and increase scope
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

  defp prewalk({:__cursor__, meta, _} = ast, acc) do
    range = {meta[:line]..meta[:line], meta[:column]..meta[:column]}

    acc =
      Map.put(acc, :cursor, %{
        range: range,
        scope: acc.scope
      })

    {ast, acc}
  end

  # find variable
  defp prewalk({name, meta, nil} = ast, acc) do
    range = calculate_range(name, meta[:line], meta[:column])
    type = if range in acc.sym_ranges, do: :sym, else: :ref
    var = {type, name, range, acc.scope}

    acc = collect_var(acc, var)

    {ast, acc}
  end

  defp prewalk(ast, acc) do
    {ast, acc}
  end

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

    {line..line, column..(column + length - 1)}
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
