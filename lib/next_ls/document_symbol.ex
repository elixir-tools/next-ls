defmodule NextLS.DocumentSymbol do
  @moduledoc false

  alias GenLSP.Structures.DocumentSymbol
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range

  # we set the literal encoder so that we can know when atoms and strings start and end
  # this makes it useful for knowing the exact locations of struct field definitions
  @spec fetch(text :: String.t()) :: list(DocumentSymbol.t())
  def fetch(text) do
    text
    |> Code.string_to_quoted!(
      literal_encoder: fn literal, meta ->
        if is_atom(literal) or is_binary(literal) do
          {:ok, {:__literal__, meta, [literal]}}
        else
          {:ok, literal}
        end
      end,
      unescape: false,
      token_metadata: true,
      columns: true
    )
    |> walker(nil)
    |> List.wrap()
  end

  defp walker([{{:__literal__, _, [:do]}, {_, _, _exprs} = ast}], mod) do
    walker(ast, mod)
  end

  defp walker({:__block__, _, exprs}, mod) do
    for expr <- exprs, sym = walker(expr, mod), sym != nil do
      sym
    end
  end

  defp walker({:defmodule, meta, [name | children]}, _mod) do
    name = Macro.to_string(unliteral(name))

    %DocumentSymbol{
      name: name,
      kind: GenLSP.Enumerations.SymbolKind.module(),
      children: List.flatten(for(child <- children, sym = walker(child, name), sym != nil, do: sym)),
      range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:end][:line] - 1, character: meta[:end][:column] - 1}
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker({:describe, meta, [name | children]}, mod) do
    name = String.replace("describe " <> Macro.to_string(unliteral(name)), "\n", "")

    %DocumentSymbol{
      name: name,
      kind: GenLSP.Enumerations.SymbolKind.class(),
      children: List.flatten(for(child <- children, sym = walker(child, mod), sym != nil, do: sym)),
      range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:end][:line] - 1, character: meta[:end][:column] - 1}
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker({:defstruct, meta, [fields]}, mod) do
    fields =
      for field <- fields do
        {name, start_line, start_column} =
          case field do
            {:__literal__, meta, [name]} ->
              start_line = meta[:line] - 1
              start_column = meta[:column] - 1
              name = Macro.to_string(name)

              {name, start_line, start_column}

            {{:__literal__, meta, [name]}, default} ->
              start_line = meta[:line] - 1
              start_column = meta[:column] - 1
              name = to_string(name) <> ": " <> Macro.to_string(unliteral(default))

              {name, start_line, start_column}
          end

        %DocumentSymbol{
          name: name,
          children: [],
          kind: GenLSP.Enumerations.SymbolKind.field(),
          range: %Range{
            start: %Position{
              line: start_line,
              character: start_column
            },
            end: %Position{
              line: start_line,
              character: start_column + String.length(name)
            }
          },
          selection_range: %Range{
            start: %Position{line: start_line, character: start_column},
            end: %Position{line: start_line, character: start_column}
          }
        }
      end

    %DocumentSymbol{
      name: "%#{mod}{}",
      children: fields,
      kind: elixir_kind_to_lsp_kind(:defstruct),
      range: %Range{
        start: %Position{
          line: meta[:line] - 1,
          character: meta[:column] - 1
        },
        end: %Position{
          line: (meta[:end_of_expression][:line] || meta[:line]) - 1,
          character: (meta[:end_of_expression][:column] || meta[:column]) - 1
        }
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker({:@, meta, [{_name, _, value}]} = attribute, _) when length(value) > 0 do
    %DocumentSymbol{
      name: attribute |> unliteral() |> Macro.to_string() |> String.replace("\n", ""),
      children: [],
      kind: elixir_kind_to_lsp_kind(:@),
      range: %Range{
        start: %Position{
          line: meta[:line] - 1,
          character: meta[:column] - 1
        },
        end: %Position{
          line: (meta[:end_of_expression] || meta)[:line] - 1,
          character: (meta[:end_of_expression] || meta)[:column] - 1
        }
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker({type, meta, [name | _children]}, _) when type in [:test, :feature, :property] do
    %DocumentSymbol{
      name: String.replace("#{type} #{Macro.to_string(unliteral(name))}", "\n", ""),
      children: [],
      kind: GenLSP.Enumerations.SymbolKind.constructor(),
      range: %Range{
        start: %Position{
          line: meta[:line] - 1,
          character: meta[:column] - 1
        },
        end: %Position{
          line: (meta[:end] || meta[:end_of_expression] || meta)[:line] - 1,
          character: (meta[:end] || meta[:end_of_expression] || meta)[:column] - 1
        }
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker({type, meta, [name | _children]}, _) when type in [:def, :defp, :defmacro, :defmacro] do
    %DocumentSymbol{
      name: String.replace("#{type} #{name |> unliteral() |> Macro.to_string()}", "\n", ""),
      children: [],
      kind: elixir_kind_to_lsp_kind(type),
      range: %Range{
        start: %Position{
          line: meta[:line] - 1,
          character: meta[:column] - 1
        },
        end: %Position{
          line: (meta[:end] || meta[:end_of_expression] || meta)[:line] - 1,
          character: (meta[:end] || meta[:end_of_expression] || meta)[:column] - 1
        }
      },
      selection_range: %Range{
        start: %Position{line: meta[:line] - 1, character: meta[:column] - 1},
        end: %Position{line: meta[:line] - 1, character: meta[:column] - 1}
      }
    }
  end

  defp walker(_ast, _) do
    nil
  end

  defp unliteral(ast) do
    Macro.prewalk(ast, fn
      {:__literal__, _, [literal]} ->
        literal

      node ->
        node
    end)
  end

  defp elixir_kind_to_lsp_kind(:defstruct), do: GenLSP.Enumerations.SymbolKind.struct()
  defp elixir_kind_to_lsp_kind(:@), do: GenLSP.Enumerations.SymbolKind.property()

  defp elixir_kind_to_lsp_kind(kind) when kind in [:def, :defp, :defmacro, :defmacrop, :test, :describe],
    do: GenLSP.Enumerations.SymbolKind.function()
end
