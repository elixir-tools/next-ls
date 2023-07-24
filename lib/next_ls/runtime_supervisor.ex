defmodule NextLS.RuntimeSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    children = [
      {NextLS.Runtime, init_arg[:runtime]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
