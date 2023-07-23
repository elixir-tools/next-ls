defmodule NextLS.Runtime.Sidecar do
  @moduledoc false
  use GenServer

  alias NextLS.SymbolTable

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.take(args, [:symbol_table]), Keyword.take(args, [:name]))
  end

  def init(args) do
    symbol_table = Keyword.fetch!(args, :symbol_table)
    {:ok, %{symbol_table: symbol_table}}
  end

  def handle_info({:tracer, payload}, state) do
    SymbolTable.put_symbols(state.symbol_table, payload)
    {:noreply, state}
  end

  def handle_info({{:tracer, :reference}, payload}, state) do
    SymbolTable.put_reference(state.symbol_table, payload)
    {:noreply, state}
  end
end
