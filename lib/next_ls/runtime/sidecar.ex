defmodule NextLS.Runtime.Sidecar do
  @moduledoc false
  use GenServer

  alias NextLS.ASTHelpers
  alias NextLS.DB

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.drop(args, [:name]), Keyword.take(args, [:name]))
  end

  def init(args) do
    db = Keyword.fetch!(args, :db)

    {:ok, %{db: db}}
  end

  def handle_info({:tracer, payload}, state) do
    attributes = ASTHelpers.get_module_attributes(payload.file, payload.module)
    payload = Map.put_new(payload, :symbols, attributes)
    DB.insert_symbol(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference, :attribute}, payload}, state) do
    name = ASTHelpers.get_attribute_reference_name(payload.file, payload.meta[:line], payload.meta[:column])
    if name, do: DB.insert_reference(state.db, %{payload | identifier: name})

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference}, payload}, state) do
    DB.insert_reference(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :start}, filename}, state) do
    DB.clean_references(state.db, filename)

    {:noreply, state}
  end
end
