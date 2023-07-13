defmodule NextLS.Definition do
  alias NextLS.ReferenceTable

  def fetch(file, position, dets_symbol_table, dets_ref_table) do
    ref = ReferenceTable.reference(dets_ref_table, file, position)

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
