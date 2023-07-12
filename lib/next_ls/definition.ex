defmodule NextLS.Definition do
  def fetch(file, {line, col}, dets_symbol_table, dets_ref_table) do
    ref =
      dets_ref_table
      |> :dets.lookup(file)
      |> Enum.find(fn
        {_file, {{{begin_line, begin_col}, {end_line, end_col}}, _ref}} ->
          line >= begin_line && col >= begin_col && line <= end_line && col <= end_col
      end)

    # :dets.traverse(dets_symbol_table, fn x -> {:continue, x} end) |> dbg
    # :dets.traverse(dets_ref_table, fn x -> {:continue, x} end) |> dbg

    # dbg(ref)

    query =
      case ref do
        {_file, {_range, %{type: :alias} = ref}} ->
          [
            {{:_, %{line: :"$3", name: :"$2", file: :"$5", module: :"$1", col: :"$4"}},
             [
               {:andalso, {:==, :"$1", ref.module}, {:==, :"$2", Macro.to_string(ref.module)}}
             ], [{{:"$5", :"$3", :"$4"}}]}
          ]

        {_file, {_range, %{type: :function} = ref}} ->
          [
            {{:_, %{line: :"$3", name: :"$2", file: :"$5", module: :"$1", col: :"$4"}},
             [
               {:andalso, {:==, :"$1", ref.module}, {:==, :"$2", ref.identifier}}
             ], [{{:"$5", :"$3", :"$4"}}]}
          ]

        _ ->
          nil
      end

    if query do
      :dets.select(dets_symbol_table, query)
    else
      nil
    end
  end
end
