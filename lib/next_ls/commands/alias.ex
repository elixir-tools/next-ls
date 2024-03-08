defmodule NextLS.Commands.Alias do
  @moduledoc false
  import Schematic

  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ASTHelpers
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  defp opts do
    map(%{
      position: Position.schematic(),
      uri: str(),
      text: list(str())
    })
  end

  def run(opts) do
    with {:ok, %{text: text, uri: uri, position: position}} <- unify(opts(), Map.new(opts)),
         {:ok, ast} = parse(text),
         {:ok, defm} <- ASTHelpers.get_nearest_module(ast, position),
         {:ok, {{:., _contenxt, [{:__aliases__, _, modules} | _]}, _, _}} <- get_node(ast, position) do
      range = make_range(defm)
      indent = EditHelpers.get_indent(text, range.start.line)
      aliased = get_aliased(defm, modules)

      %WorkspaceEdit{
        changes: %{
          uri => [
            %TextEdit{
              new_text:
                EditHelpers.add_indent_to_edit(
                  Macro.to_string(aliased),
                  indent
                ),
              range: range
            }
          ]
        }
      }
    else
      {:error, message} ->
        %GenLSP.ErrorResponse{code: ErrorCodes.parse_error(), message: inspect(message)}
    end
  end

  defp parse(lines) do
    lines
    |> Enum.join("\n")
    |> Spitfire.parse()
    |> case do
      {:error, ast, _errors} ->
        {:ok, ast}

      other ->
        other
    end
  end

  defp make_range(original_ast) do
    range = Sourceror.get_range(original_ast)

    %Range{
      start: %Position{line: range.start[:line] - 1, character: range.start[:column] - 1},
      end: %Position{line: range.end[:line] - 1, character: range.end[:column] - 1}
    }
  end

  def get_node(ast, pos) do
    pos = [line: pos.line + 1, column: pos.character + 1]

    result =
      ast
      |> Z.zip()
      |> Z.traverse(nil, fn tree, acc ->
        node = Z.node(tree)
        range = Sourceror.get_range(node)

        if not is_nil(range) and
             match?({{:., _, [{:__aliases__, _context, _modules} | _]}, _, _args}, node) &&
             Sourceror.compare_positions(range.start, pos) == :lt &&
             Sourceror.compare_positions(range.end, pos) == :gt do
          {tree, node}
        else
          {tree, acc}
        end
      end)

    case result do
      {_, nil} ->
        {:error, "could not find a module to alias at the cursor position"}

      {_, {_t, _m, []}} ->
        {:error, "could not find a module to alias at the cursor position"}

      {_, {_t, _m, [_argument | _rest]} = node} ->
        {:ok, node}
    end
  end

  defp get_aliased(defm, modules) do
    last = List.last(modules)

    replaced =
      Macro.prewalk(defm, fn
        {:__aliases__, context, ^modules} -> {:__aliases__, context, [last]}
        ast -> ast
      end)

    alias_to_add = {:alias, [alias: false], [{:__aliases__, [], modules}]}

    {:defmodule, context, [module, [do: block]]} = replaced

    case block do
      {:__block__, block_context, defs} ->
        {:defmodule, context, [module, [do: {:__block__, block_context, [alias_to_add | defs]}]]}

      {_, _, _} = original ->
        {:defmodule, context, [module, [do: {:__block__, [], [alias_to_add, original]}]]}
    end
  end
end
