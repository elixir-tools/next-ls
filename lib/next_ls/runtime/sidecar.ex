defmodule NextLS.Runtime.Sidecar do
  @moduledoc false
  use GenServer

  alias NextLS.DB

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.take(args, [:symbol_table, :db]), Keyword.take(args, [:name]))
  end

  def init(args) do
    symbol_table = Keyword.fetch!(args, :symbol_table)
    db = Keyword.fetch!(args, :db)

    {:ok, %{symbol_table: symbol_table, db: db}}
  end

  def handle_info({:tracer, payload}, state) do
    dbg(Process.info(self(), :message_queue_len))
    DB.insert_symbol(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference}, payload}, state) do
    dbg(Process.info(self(), :message_queue_len))
    DB.insert_reference(state.db, payload)

    {:noreply, state}
  end
end
