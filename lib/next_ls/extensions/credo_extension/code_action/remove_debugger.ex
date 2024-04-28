defmodule NextLS.CredoExtension.CodeAction.RemoveDebugger do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit
  alias NextLS.EditHelpers
  alias Sourceror.Zipper, as: Z

  @line_length 121

  def new(%Diagnostic{} = diagnostic, text, uri) do
    range = diagnostic.range

    with {:ok, ast, comments} <- parse(text),
         {:ok, debugger_node} <- find_debugger(ast, range) do
      indent = EditHelpers.get_indent(text, range.start.line)
      ast_without_debugger = remove_debugger(debugger_node)
      range = make_range(debugger_node)

      comments =
        Enum.filter(comments, fn comment ->
          comment.line > range.start.line && comment.line <= range.end.line
        end)

      to_algebra_opts = [comments: comments]
      doc = Code.quoted_to_algebra(ast_without_debugger, to_algebra_opts)
      formatted = doc |> Inspect.Algebra.format(@line_length) |> IO.iodata_to_binary()

      [
        %CodeAction{
          title: make_title(debugger_node),
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
      _ ->
        []
    end
  end

  defp find_debugger(ast, range) do
    pos = %{
      start: [line: range.start.line + 1, column: range.start.character + 1],
      end: [line: range.end.line + 1, column: range.end.character + 1]
    }

    {_, results} =
      ast
      |> Z.zip()
      |> Z.traverse([], fn tree, acc ->
        node = Z.node(tree)
        range = Sourceror.get_range(node)

        # range.start <= diagnostic_pos.start <= diagnostic_pos.end <= range.end
        if (matches_debug?(node) || matches_pipe?(node)) && range &&
             Sourceror.compare_positions(range.start, pos.start) in [:lt, :eq] &&
             Sourceror.compare_positions(range.end, pos.end) in [:gt, :eq] do
          {tree, [node | acc]}
        else
          {tree, acc}
        end
      end)

    result =
      Enum.min_by(results, fn node ->
        range = Sourceror.get_range(node)

        pos.start[:column] - range.start[:column] + range.end[:column] - pos.end[:column]
      end)

    result =
      Enum.find(results, result, fn
        {:|>, _, [_first, ^result]} -> true
        _ -> false
      end)

    case result do
      nil -> {:error, "could find a debugger to remove"}
      node -> {:ok, node}
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

  defp matches_pipe?({:|>, _, [_, arg]}), do: matches_debug?(arg)
  defp matches_pipe?(_), do: false

  defp matches_debug?({:dbg, _, _}), do: true

  defp matches_debug?({{:., _, [{:__aliases__, _, [:IO]}, f]}, _, _}) when f in [:puts, :inspect], do: true

  defp matches_debug?({{:., _, [{:__aliases__, _, [:IEx]}, :pry]}, _, _}), do: true
  defp matches_debug?({{:., _, [{:__aliases__, _, [:Mix]}, :env]}, _, _}), do: true
  defp matches_debug?({{:., _, [{:__aliases__, _, [:Kernel]}, :dbg]}, _, _}), do: true
  defp matches_debug?(_), do: false

  defp remove_debugger({:|>, _, [arg, _function]}), do: arg
  defp remove_debugger({{:., _, [{:__aliases__, _, [:IO]}, :inspect]}, _, [arg | _]}), do: arg
  defp remove_debugger({{:., _, [{:__aliases__, _, [:Kernel]}, :dbg]}, _, [arg | _]}), do: arg
  defp remove_debugger({:dbg, _, [arg | _]}), do: arg
  defp remove_debugger(_node), do: {:__block__, [], []}

  defp make_title({_, ctx, _} = node), do: "Remove `#{format_node(node)}` #{ctx[:line]}:#{ctx[:column]}"
  defp format_node({:|>, _, [_arg, function]}), do: format_node(function)

  defp format_node({{:., _, [{:__aliases__, _, [module]}, function]}, _, args}),
    do: "&#{module}.#{function}/#{Enum.count(args)}"

  defp format_node({:dbg, _, args}), do: "&dbg/#{Enum.count(args)}"
  defp format_node(node), do: Macro.to_string(node)
end
