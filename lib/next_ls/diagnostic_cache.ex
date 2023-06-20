defmodule NextLS.DiagnosticCache do
  # TODO: this should be an ETS table
  @moduledoc false
  use Agent

  def start_link(opts) do
    Agent.start_link(fn -> Map.new() end, Keyword.take(opts, [:name]))
  end

  def get(cache) do
    Agent.get(cache, & &1)
  end

  def put(cache, namespace, filename, diagnostic) do
    Agent.update(cache, fn cache ->
      Map.update(cache, namespace, %{filename => [diagnostic]}, fn cache ->
        Map.update(cache, filename, [diagnostic], fn v ->
          [diagnostic | v]
        end)
      end)
    end)
  end

  def clear(cache, namespace) do
    Agent.update(cache, fn cache ->
      Map.update(cache, namespace, %{}, fn cache ->
        for {k, _} <- cache, into: Map.new() do
          {k, []}
        end
      end)
    end)
  end
end
