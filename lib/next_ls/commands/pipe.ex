defmodule NextLS.Commands.Pipe do
  @moduledoc false
  import Schematic

  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  defp opts do
    map(%{
      position: Position.schematic(),
      uri: str(),
      text: list(str())
    })
  end

  def to(opts) do
    with {:ok, %{text: text, uri: uri, position: position}} <- unify(opts(), Map.new(opts)),
         {:ok, ast} = parse(text),
         {:ok, {t, m, [argument | rest]} = original} <- get_node(ast, position) do
      range = make_range(original)
      indent = EditHelpers.get_indent(text, range.start.line)
      piped = {:|>, [], [argument, {t, m, rest}]}

      %WorkspaceEdit{
        changes: %{
          uri => [
            %TextEdit{
              new_text:
                EditHelpers.add_indent_to_edit(
                  Macro.to_string(piped),
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

  def from(opts) do
    with {:ok, %{text: text, uri: uri, position: position}} <- unify(opts(), Map.new(opts)),
         {:ok, ast} = parse(text),
         {:ok, {:|>, _m, [left, {right, _, args}]} = original} <- get_pipe_node(ast, position) do
      range = make_range(original)
      indent = EditHelpers.get_indent(text, range.start.line)
      unpiped = {right, [], [left | args]}

      %WorkspaceEdit{
        changes: %{
          uri => [
            %TextEdit{
              new_text:
                EditHelpers.add_indent_to_edit(
                  Macro.to_string(unpiped),
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

  def decorate(code, range) do
    code
    |> Sourceror.patch_string([%{range: range, change: &"«#{&1}»"}])
    |> String.trim_trailing()
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
             (match?({{:., _, _}, _, [_ | _]}, node) or
                match?({t, _, [_ | _]} when t not in [:., :__aliases__], node)) do
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
        {:error, "could not find an argument to extract at the cursor position"}

      {_, {_t, _m, []}} ->
        {:error, "could not find an argument to extract at the cursor position"}

      {_, {_t, _m, [_argument | _rest]} = node} ->
        {:ok, node}
    end
  end

  def get_pipe_node(ast, pos) do
    pos = [line: pos.line + 1, column: pos.character + 1]

    result =
      ast
      |> Z.zip()
      |> Z.traverse(nil, fn tree, acc ->
        node = Z.node(tree)
        range = Sourceror.get_range(node)

        if not is_nil(range) and match?({:|>, _, _}, node) do
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
        {:error, "could not find a pipe operator at the cursor position"}

      {_, {_t, _m, [_argument | _rest]} = node} ->
        {:ok, node}
    end
  end
end
