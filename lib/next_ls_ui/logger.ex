defmodule NextLS.UI.Logger do
  @moduledoc false
  def log(event, _config) do
    if Process.alive?(Process.whereis(NextLS.UI.Registry)) do
      Registry.dispatch(NextLS.UI.Registry, :log_socket, fn entries ->
        for {pid, _} <- entries do
          send(pid, {:log, event})
        end
      end)
    end
  end
end
