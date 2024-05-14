defmodule NextLS.ASTHelpers do
  @moduledoc false
  alias GenLSP.Structures.Position
  alias Sourceror.Zipper

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
      file |> File.read!() |> NextLS.Parser.parse!(columns: true)
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
      {_, range} =
        code
        |> NextLS.Parser.parse!(columns: true, token_metadata: true)
        |> Macro.prewalk(nil, fn
          ast, nil = range ->
            range =
              case ast do
                {:__aliases__, meta, aliases} ->
                  if ale == List.last(aliases) do
                    found_range =
                      {{meta[:line], meta[:column]},
                       {meta[:last][:line], meta[:last][:column] + String.length(to_string(ale)) - 1}}

                    if NextLS.ASTHelpers.inside?({{start.line, start.col}, {stop.line, stop.col}}, found_range) do
                      found_range
                    else
                      range
                    end
                  else
                    range
                  end

                _ ->
                  range
              end

            {ast, range}

          ast, range ->
            {ast, range}
        end)

      range
    end
  end

  def inside?(outer, {{_, _}, {_, _}} = target) do
    {{outer_startl, outer_startc}, {outer_endl, outer_endc}} = outer
    {target_start, target_end} = target

    Enum.all?([target_start, target_end], fn {line, col} ->
      if outer_startl <= line and line <= outer_endl do
        cond do
          outer_startl < line and line < outer_endl -> true
          outer_startl == line and outer_startc <= col -> true
          outer_endl == line and col <= outer_endc -> true
          true -> false
        end
      else
        false
      end
    end)
  end

  defp sourceror_inside?(range, position) do
    Sourceror.compare_positions(range.start, position) in [:lt, :eq] &&
      Sourceror.compare_positions(range.end, position) in [:gt, :eq]
  end

  @spec get_surrounding_module(ast :: Macro.t(), position :: Position.t()) :: {:ok, Macro.t()} | {:error, String.t()}
  def get_surrounding_module(ast, position) do
    # TODO: this should take elixir positions and not LSP positions
    position = [line: position.line + 1, column: position.character + 1]

    {_zipper, acc} =
      ast
      |> Zipper.zip()
      |> Zipper.traverse_while(nil, fn tree, acc ->
        node = Zipper.node(tree)
        node_range = Sourceror.Range.get_range(node)

        is_inside =
          with nil <- node_range do
            false
          else
            _ -> sourceror_inside?(node_range, position)
          end

        acc =
          with true <- is_inside,
               {:defmodule, _, _} <- node do
            node
          else
            _ -> acc
          end

        cond do
          is_inside and match?({_, _, [_ | _]}, node) ->
            {:cont, tree, acc}

          is_inside and match?({_, _, []}, node) ->
            {:halt, tree, acc}

          true ->
            {:cont, tree, acc}
        end
      end)

    with {:ok, nil} <- {:ok, acc} do
      {:error, :not_found}
    end
  end

  def top(nil, acc, _callback), do: acc

  def top(%Zipper{path: nil} = zipper, acc, callback), do: callback.(Zipper.node(zipper), zipper, acc)

  def top(zipper, acc, callback) do
    node = Zipper.node(zipper)
    acc = callback.(node, zipper, acc)

    zipper = Zipper.up(zipper)

    top(zipper, acc, callback)
  end

  defmodule Function do
    @moduledoc false

    def find_remote_function_call_within(ast, {line, column}) do
      position = [line: line, column: column]

      result =
        ast
        |> Zipper.zip()
        |> Zipper.find(fn
          {:|>, _, [_, {{:., _, _}, _metadata, _} = func_node]} ->
            inside?(func_node, position)

          {{:., _, _}, _metadata, _} = node ->
            inside?(node, position)

          _ ->
            false
        end)

      if result do
        {:ok, Zipper.node(result)}
      else
        {:error, :not_found}
      end
    end

    def find_params_index(ast, {line, column}) do
      ast
      |> Sourceror.get_args()
      |> Enum.map(&Sourceror.get_meta/1)
      |> Enum.find_index(fn meta ->
        if meta[:closing] do
          line <= meta[:closing][:line] and line >= meta[:line]
        else
          meta[:line] == line and column <= meta[:column]
        end
      end)
    end

    defp inside?(node, position) do
      range = Sourceror.get_range(node)

      Sourceror.compare_positions(range.start, position) == :lt &&
        Sourceror.compare_positions(range.end, position) == :gt
    end
  end
end
