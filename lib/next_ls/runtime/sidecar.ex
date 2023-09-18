defmodule NextLS.Runtime.Sidecar do
  @moduledoc false
  use GenServer

  alias NextLS.ASTHelpers.Aliases
  alias NextLS.ASTHelpers.Attributes
  alias NextLS.DB

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.drop(args, [:name]), Keyword.take(args, [:name]))
  end

  def init(args) do
    db = Keyword.fetch!(args, :db)

    {:ok, %{db: db}}
  end

  def handle_info({:tracer, :dbg, term}, state) do
    dbg(term)

    {:noreply, state}
  end

  def handle_info({:tracer, payload}, state) do
    attributes = Attributes.get_module_attributes(payload.file, payload.module)
    payload = Map.put_new(payload, :symbols, attributes)
    DB.insert_symbol(state.db, payload)

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference, :alias}, payload}, state) do
    # TODO: in the next version of elixir, generated code will not have :column metadata, so we can tell if the alias is from
    # a macro. For now, just try and rescue
    try do
      if payload.meta[:end_of_expression] do
        start = %{line: payload.meta[:line], col: payload.meta[:column]}
        stop = %{line: payload.meta[:end_of_expression][:line], col: payload.meta[:end_of_expression][:column]}

        {start, stop} =
          Aliases.extract_alias_range(
            File.read!(payload.file),
            {start, stop},
            payload.identifier |> Macro.to_string() |> String.to_atom()
          )

        payload =
          payload
          |> Map.put(:identifier, payload.module)
          |> Map.put(:range, %{start: start, stop: stop})

        DB.insert_reference(state.db, payload)
      end
    rescue
      _ -> :ok
    end

    {:noreply, state}
  end

  def handle_info({{:tracer, :reference, :attribute}, payload}, state) do
    name = Attributes.get_attribute_reference_name(payload.file, payload.meta[:line], payload.meta[:column])
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

  def handle_info({{:tracer, :dbg}, payload}, state) do
    dbg(payload)
    {:noreply, state}
  end
end
