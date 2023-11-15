defmodule NextLS.Runtime.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    name = init_arg[:name]
    lsp = init_arg[:lsp]
    registry = init_arg[:registry]
    logger = init_arg[:logger]
    hidden_folder = init_arg[:path]
    File.mkdir_p!(hidden_folder)
    File.write!(Path.join(hidden_folder, ".gitignore"), "*\n")

    db_name = :"db-#{name}"
    sidecar_name = :"sidecar-#{name}"
    db_activity = :"db-activity-#{name}"

    Registry.register(registry, :runtime_supervisors, %{name: name, init_arg: init_arg})

    children = [
      {NextLS.Runtime.Sidecar, name: sidecar_name, db: db_name},
      {NextLS.DB.Activity,
       logger: logger, name: db_activity, lsp: lsp, timeout: Application.get_env(:next_ls, :indexing_timeout)},
      {NextLS.DB,
       logger: logger,
       file: "#{hidden_folder}/nextls.db",
       registry: registry,
       name: db_name,
       runtime: name,
       activity: db_activity},
      {NextLS.Runtime, init_arg[:runtime] ++ [name: name, registry: registry, parent: sidecar_name, db: db_name]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
