defmodule NextLS.ReferenceTable do
  @moduledoc false
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.take(args, [:path]), Keyword.take(args, [:name]))
  end

  @spec reference(pid() | atom(), String.t(), {integer(), integer()}) :: list(struct())
  def reference(server, file, position), do: GenServer.call(server, {:reference, file, position})

  @spec put_reference(pid() | atom(), map()) :: :ok
  def put_reference(server, reference), do: GenServer.cast(server, {:put_reference, reference})

  @spec close(pid() | atom()) :: :ok | {:error, term()}
  def close(server), do: GenServer.call(server, :close)

  def init(args) do
    path = Keyword.fetch!(args, :path)
    reference_table_name = Keyword.get(args, :reference_table_name, :reference_table)

    File.mkdir_p!(path)

    {:ok, ref_name} =
      :dets.open_file(reference_table_name,
        file: path |> Path.join("reference_table.dets") |> String.to_charlist(),
        type: :duplicate_bag
      )

    {:ok, %{table: ref_name}}
  end

  def handle_call({:reference, file, {line, col}}, _, state) do
    ref =
      :dets.select(
        state.table,
        [
          {{{:"$1", {{:"$2", :"$3"}, {:"$4", :"$5"}}}, :"$6"},
           [
             {:andalso,
              {:andalso, {:andalso, {:andalso, {:==, :"$1", file}, {:"=<", :"$2", line}}, {:"=<", :"$3", col}},
               {:"=<", line, :"$4"}}, {:"=<", col, :"$5"}}
           ], [:"$6"]}
        ]
      )

    {:reply, ref, state}
  end

  def handle_call(:close, _, state) do
    :dets.close(state.table)

    {:reply, :ok, state}
  end

  def handle_cast({:put_reference, reference}, state) do
    %{
      meta: meta,
      identifier: identifier,
      file: file
    } = reference

    col = meta[:column] || 0

    identifier_length = identifier |> to_string() |> String.replace("Elixir.", "") |> String.length()

    range = {{meta[:line], col}, {meta[:line], col + identifier_length}}

    :dets.insert(state.table, {{file, range}, reference})

    {:noreply, state}
  end
end
