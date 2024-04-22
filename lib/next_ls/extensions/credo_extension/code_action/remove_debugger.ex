defmodule NextLS.CredoExtension.CodeAction.RemoveDebugger do
  @moduledoc false

  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.ASTHelpers
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  @line_length 121

  def new(diagnostic, text, uri) do
    %Diagnostic{range: range} = diagnostic

    with {:ok, ast, comments} <- parse(text),
         {:ok, defm} <- ASTHelpers.get_surrounding_module(ast, range.start) do
      range = make_range(defm)
      indent = EditHelpers.get_indent(text, range.start.line)
      diagnostic.range.start
      ast_without_debugger = remove_debugger(defm, diagnostic.range.start)

      comments =
        Enum.filter(comments, fn comment ->
          comment.line > range.start.line && comment.line <= range.end.line
        end)

      to_algebra_opts = [comments: comments]
      doc = Code.quoted_to_algebra(ast_without_debugger, to_algebra_opts)
      formatted = doc |> Inspect.Algebra.format(@line_length) |> IO.iodata_to_binary()

      [
        %CodeAction{
          title: "Remove debugger",
          diagnostics: [diagnostic],
          edit: %WorkspaceEdit{
            changes: %{
              uri => [
                %TextEdit{
                  new_text: EditHelpers.add_indent_to_edit(formatted, indent),
                  range: range
                }
              ]
            }
          }
        }
      ]
    else
      {:error, message} ->
        %GenLSP.ErrorResponse{code: ErrorCodes.parse_error(), message: inspect(message)}
    end
  end

  defp remove_debugger(ast, position) do
    pos = [line: position.line + 1, column: position.character + 1]

    ast
    |> Z.zip()
    |> Z.traverse(fn tree ->
      node = Z.node(tree)
      range = Sourceror.get_range(node)

      if (matches_debug?(node, pos) || matches_pipe?(node, pos)) &&
           Sourceror.compare_positions(range.start, pos) in [:lt, :eq] &&
           Sourceror.compare_positions(range.end, pos) in [:gt, :eq] do
        handle(node, tree)
      else
        tree
      end
    end)
    |> Z.node()
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

  defp matches_pipe?({:|>, ctx, [_, arg]}, pos), do: pos[:line] == ctx[:line] && matches_debug?(arg, pos)
  defp matches_pipe?(_, _), do: false

  defp matches_debug?({:dbg, ctx, []}, pos), do: pos[:line] == ctx[:line]

  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:IO]}, f]}, _, _}, pos) when f in [:puts, :inspect],
    do: pos[:line] == ctx[:line]

  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:IEx]}, :pry]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:Mix]}, :env]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?({{:., ctx, [{:__aliases__, _, [:Kernel]}, :dbg]}, _, _}, pos), do: pos[:line] == ctx[:line]
  defp matches_debug?({{:__block__, _ctx1, _}, expr}, pos), do: matches_debug?(expr, pos)
  defp matches_debug?(_, _), do: false

  defp handle({:|>, _, [arg, _function]}, tree), do: Z.replace(tree, arg)
  defp handle({{:__block__, _, _}, _expr}, tree), do: Z.replace(tree, {:do, {:__block__, [], []}})
  defp handle(_, tree), do: Z.remove(tree)
end
