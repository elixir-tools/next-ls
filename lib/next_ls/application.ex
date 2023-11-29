defmodule NextLS.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Logger.add_handlers(:next_ls)

    if Application.get_env(:next_ls, :otel, false) do
      NextLS.OpentelemetrySchematic.setup()
      NextLS.OpentelemetryGenLSP.setup()
    end

    case System.cmd("epmd", ["-daemon"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        IO.warn("Failed to start epmd! Exited with code=#{code} and output=#{output}")

        raise "Failed to start epmd!"
    end

    Node.start(:"next-ls-#{System.system_time()}", :shortnames)

    children = [NextLS.LSPSupervisor]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NextLS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
