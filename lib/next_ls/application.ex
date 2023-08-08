defmodule NextLS.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Node.start(:"next-ls-#{System.system_time()}", :shortnames)

    children = [NextLS.LSPSupervisor]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NextLS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
