defmodule NextLS.Definition do
  def fetch(file, {line, col}, dets_symbol_table, dets_ref_table) do
    ref =
      :dets.select(
        dets_ref_table,
        [
          {{{:"$1", {{:"$2", :"$3"}, {:"$4", :"$5"}}}, :"$6"},
           [
             {:andalso,
              {:andalso, {:andalso, {:andalso, {:==, :"$1", file}, {:"=<", :"$2", line}}, {:"=<", :"$3", col}},
               {:"=<", line, :"$4"}}, {:"=<", col, :"$5"}}
           ], [:"$6"]}
        ]
      )

    # :dets.traverse(dets_symbol_table, fn x -> {:continue, x} end) |> dbg
    # :dets.traverse(dets_ref_table, fn x -> {:continue, x} end) |> dbg

    # dbg(ref)

    query =
      case ref do
        [%{type: :alias} = ref] ->
          [
            {{:_, %{line: :"$3", name: :"$2", file: :"$5", module: :"$1", col: :"$4"}},
             [
               {:andalso, {:==, :"$1", ref.module}, {:==, :"$2", Macro.to_string(ref.module)}}
             ], [{{:"$5", :"$3", :"$4"}}]}
          ]

        [%{type: :function} = ref] ->
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
