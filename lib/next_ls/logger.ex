defmodule NextLS.Logger do
  @moduledoc false
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, Keyword.take(arg, [:name]))
  end

  def log(server, msg), do: GenServer.cast(server, {:log, :log, msg})
  def error(server, msg), do: GenServer.cast(server, {:log, :error, msg})
  def info(server, msg), do: GenServer.cast(server, {:log, :info, msg})
  def warning(server, msg), do: GenServer.cast(server, {:log, :warning, msg})

  def init(args) do
    lsp = Keyword.fetch!(args, :lsp)
    {:ok, %{lsp: lsp}}
  end

  def handle_cast({:log, type, msg}, state) do
    apply(GenLSP, type, [state.lsp, String.trim("[NextLS] #{msg}")])
    {:noreply, state}
  end
end
