defmodule NextLS.ASTHelpers.Env do
  @moduledoc false
  alias Sourceror.Zipper

  defp inside?(range, position) do
    Sourceror.compare_positions(range.start, position) == :lt && Sourceror.compare_positions(range.end, position) == :gt
  end

  def build(ast) do
    cursor =
      ast
      |> Zipper.zip()
      |> Zipper.find(fn
        {:__cursor__, _, _} -> true
        _ -> false
      end)

    position = cursor |> Zipper.node() |> Sourceror.get_range() |> Map.get(:start)
    zipper = Zipper.prev(cursor)

    env =
      ascend(zipper, %{variables: []}, fn node, zipper, acc ->
        is_inside =
          with {_, _, _} <- node,
               range when not is_nil(range) <- Sourceror.get_range(node) do
            inside?(range, position)
          else
            _ ->
              false
          end

        case node do
          {match_op, _, [pm | _]} when match_op in [:=] and not is_inside ->
            {_, vars} =
              Macro.prewalk(pm, [], fn node, acc ->
                case node do
                  {name, _, nil} ->
                    {node, [to_string(name) | acc]}

                  _ ->
                    {node, acc}
                end
              end)

            Map.update!(acc, :variables, &(vars ++ &1))

          {match_op, _, [pm | _]} when match_op in [:<-] ->
            up_node = zipper |> Zipper.up() |> Zipper.node()

            # in_match operator comes with for and with normally, so we need to 
            # check if we are inside the parent node, which is the for/with
            is_inside =
              with {_, _, _} <- up_node,
                   range when not is_nil(range) <- Sourceror.get_range(up_node) do
                inside?(range, position)
              else
                _ ->
                  false
              end

            if is_inside do
              {_, vars} =
                Macro.prewalk(pm, [], fn node, acc ->
                  case node do
                    {name, _, nil} ->
                      {node, [to_string(name) | acc]}

                    _ ->
                      {node, acc}
                  end
                end)

              Map.update!(acc, :variables, &(vars ++ &1))
            else
              acc
            end

          {def, _, [{_, _, args} | _]} when def in [:def, :defp, :defmacro, :defmacrop] and args != [] and is_inside ->
            {_, vars} =
              Macro.prewalk(args, [], fn node, acc ->
                case node do
                  {name, _, nil} ->
                    {node, [to_string(name) | acc]}

                  _ ->
                    {node, acc}
                end
              end)

            Map.update!(acc, :variables, &(vars ++ &1))

          {:->, _, [args | _]} when args != [] ->
            {_, vars} =
              Macro.prewalk(args, [], fn node, acc ->
                case node do
                  {name, _, nil} ->
                    {node, [to_string(name) | acc]}

                  _ ->
                    {node, acc}
                end
              end)

            Map.update!(acc, :variables, &(vars ++ &1))

          _ ->
            acc
        end
      end)

    %{
      variables: Enum.uniq(env.variables)
    }
  end

  def ascend(nil, acc, _callback), do: acc

  def ascend(%Zipper{path: nil} = zipper, acc, callback), do: callback.(Zipper.node(zipper), zipper, acc)

  def ascend(zipper, acc, callback) do
    node = Zipper.node(zipper)
    acc = callback.(node, zipper, acc)

    zipper =
      cond do
        match?({:->, _, _}, node) ->
          Zipper.up(zipper)

        true ->
          left = Zipper.left(zipper)
          if left, do: left, else: Zipper.up(zipper)
      end

    ascend(zipper, acc, callback)
  end
end
