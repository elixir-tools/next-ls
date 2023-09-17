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
end
