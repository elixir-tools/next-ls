defmodule NextLS.Commands.Variables do
  @moduledoc false
  import Schematic

  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ASTHelpers
  alias NextLS.ASTHelpers.Variables
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  defp opts do
    map(%{
      position: Position.schematic(),
      uri: str(),
      text: list(str())
    })
  end

  def extract(opts) do
    with {:ok, %{text: text, uri: uri, position: position}} <- unify(opts(), Map.new(opts)),
         {:ok, ast, comments} = parse(text),
         {:ok, defm} <- ASTHelpers.get_surrounding_module(ast, position),
         {:ok, assign} <- get_node(ast, position) do
      range = make_range(defm)
      indent = EditHelpers.get_indent(text, range.start.line)
      extracted = extract_variable(defm, assign)

      comments =
        Enum.filter(comments, fn comment ->
          comment.line > range.start.line && comment.line <= range.end.line
        end)

      formatted = EditHelpers.to_string(extracted, comments)

      %WorkspaceEdit{
        changes: %{
          uri => [
            %TextEdit{
              new_text:
                EditHelpers.add_indent_to_edit(
                  formatted,
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
    |> Spitfire.parse_with_comments(literal_encoder: &{:ok, {:__block__, &2, [&1]}})
    |> case do
      {:error, ast, comments, _errors} ->
        {:ok, ast, comments}

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
             match?({:=, _match_ctx, [{_variable, _ctx, nil}, _value]}, node) do
          if Sourceror.compare_positions(range.start, pos) == :lt &&
               Sourceror.compare_positions(range.end, pos) == :gt do
            {tree, node}
          else
            {tree, acc}
          end
        else
          {tree, acc}
        end
      end)

    case result do
      {_, nil} ->
        {:error, "could not find a variable to extract at the cursor position"}

      {_, {:=, _, [{_name, _, nil}, _value]} = node} ->
        {:ok, node}
    end
  end

  defp extract_variable(defm, {:=, _, [{name, var_ctx, _} = var, value]} = assign) do
    definition = {:@, [], [{name, [], [value]}]}
    usage = {:@, [], [var]}

    refs = Variables.list_variable_references(defm, {var_ctx[:line], var_ctx[:column]})
    refs_ctx = Enum.map(refs, fn {_, {line.._line_end//_, column.._column_end//_}} -> {line, column} end)

    replaced =
      defm
      |> Z.zip()
      |> Z.traverse(fn zipper ->
        node = Z.node(zipper)

        case node do
          ^assign ->
            Z.remove(zipper)

          {^name, ctx, _} ->
            if {ctx[:line], ctx[:column]} in refs_ctx do
              Z.replace(zipper, usage)
            else
              zipper
            end

          _ ->
            zipper
        end
      end)
      |> Z.node()

    {:defmodule, context, [module, [{do_block, block}]]} = replaced

    case block do
      {:__block__, block_context, defs} ->
        {:defmodule, context, [module, [{do_block, {:__block__, block_context, [definition | defs]}}]]}

      {_, _, _} = original ->
        {:defmodule, context, [module, [{do_block, {:__block__, [], [definition, original]}}]]}
    end
  end
end
