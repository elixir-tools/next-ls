defmodule NextLS.Runtime.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    name = init_arg[:name]
    registry = init_arg[:registry]
    hidden_folder = init_arg[:path]
    File.mkdir_p!(hidden_folder)
    File.write!(Path.join(hidden_folder, ".gitignore"), "*\n")

    symbol_table_name = :"symbol-table-#{name}"
    sidecar_name = :"sidecar-#{name}"

    Registry.register(registry, :runtime_supervisors, %{name: name})

    children = [
      {NextLS.SymbolTable, workspace: name, path: hidden_folder, registry: registry, name: symbol_table_name},
      {NextLS.Runtime.Sidecar, name: sidecar_name, symbol_table: symbol_table_name},
      {NextLS.Runtime, init_arg[:runtime] ++ [name: name, registry: registry, parent: sidecar_name]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
