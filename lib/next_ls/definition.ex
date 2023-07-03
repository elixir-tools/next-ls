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

    :dets.traverse(dets_symbol_table, fn x -> {:continue, x} end)

    case ref do
      [ref] ->
        :dets.select(
          dets_symbol_table,
          [
            {{:_, %{line: :"$3", name: :"$2", module: :"$1", col: :"$4", file: :"$5"}},
             [{:andalso, {:==, :"$1", ref.module}, {:==, :"$2", ref.func}}], [{{:"$5", :"$3", :"$4"}}]}
          ]
        )

      _ ->
        nil
    end
  end
end
