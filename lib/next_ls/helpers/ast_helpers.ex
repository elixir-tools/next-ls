defmodule NextLS.ASTHelpers do
  @moduledoc false
  alias GenLSP.Structures.Position

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

  @spec get_nearest_module(ast :: Macro.t(), position :: Position.t()) :: {:ok, Macro.t()} | {:error, String.t()}
  def get_nearest_module(ast, position) do
    defm =
      ast
      |> Macro.prewalker()
      |> Enum.filter(fn node -> match?({:defmodule, _, _}, node) end)
      |> Enum.min_by(
        fn {_, ctx, _} ->
          abs(ctx[:line] - 1 - position.line)
        end,
        fn -> nil end
      )

    if defm do
      {:ok, defm}
    else
      {:error, "no defmodule definition"}
    end
  end
end
