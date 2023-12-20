defmodule NextLS.DiagnosticCache do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    opts = Keyword.take(opts, [:name])
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    name = opts[:name]

    ets =
      if name do
        :ets.new(name, [:named_table, :protected, :bag, {:read_concurrency, true}])
      else
        :ets.new(:diagnostic_cache, [:protected, :bag, {:read_concurrency, true}])
      end

    {:ok, %{ets: ets}}
  end

  def get(cache) do
    cache
    |> GenServer.call(:all)
    |> to_map()
  end

  def get(cache, namespace) do
    GenServer.call(cache, {:get, namespace})
  end

  def put(cache, namespace, filename, diagnostic) do
    GenServer.call(cache, {:put, filename, namespace, diagnostic})
  end

  def clear(cache, namespace) do
    GenServer.call(cache, {:clear, namespace})
  end

  def handle_call(:all, _from, %{ets: ets} = state) do
    result = :ets.tab2list(ets)
    {:reply, result, state}
  end

  def handle_call({:get, namespace}, _from, %{ets: ets} = state) do
    result = :ets.lookup(ets, namespace)
    {:reply, result, state}
  end

  def handle_call({:put, namespace, filename, diagnostic}, _from, %{ets: ets} = state) do
    :ets.insert(ets, {filename, namespace, diagnostic})
    {:reply, :ok, state}
  end

  def handle_call({:clear, namespace}, _from, %{ets: ets} = state) do
    :ets.delete(ets, namespace)
    {:reply, :ok, state}
  end

  defp to_map(list) do
    for {namespace, filename, diagnostic} <- list, reduce: %{} do
      d ->
        Map.update(d, namespace, %{filename => [diagnostic]}, fn value ->
          Map.update(value, filename, [diagnostic], fn diagnostics -> [diagnostic | diagnostics] end)
        end)
    end
  end
end
