defmodule NextLS.CredoExtension do
  @moduledoc false
  use GenServer

  alias GenLSP.Enumerations.DiagnosticSeverity
  alias GenLSP.Structures.CodeDescription
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias NextLS.DiagnosticCache
  alias NextLS.Runtime

  def start_link(args) do
    GenServer.start_link(
      __MODULE__,
      Keyword.take(args, [:cache, :registry, :publisher, :task_supervisor]),
      Keyword.take(args, [:name])
    )
  end

  @impl GenServer
  def init(args) do
    cache = Keyword.fetch!(args, :cache)
    registry = Keyword.fetch!(args, :registry)
    publisher = Keyword.fetch!(args, :publisher)
    task_supervisor = Keyword.fetch!(args, :task_supervisor)

    Registry.register(registry, :extensions, :credo)

    {:ok,
     %{
       runtimes: Map.new(),
       cache: cache,
       registry: registry,
       task_supervisor: task_supervisor,
       publisher: publisher,
       refresh_refs: Map.new()
     }}
  end

  @impl GenServer

  def handle_info({:runtime_ready, _, _}, state), do: {:noreply, state}

  def handle_info({:compiler, _diagnostics}, state) do
    {state, refresh_refs} =
      dispatch(state.registry, :runtimes, fn entries ->
        # loop over runtimes
        for {runtime, %{path: path}} <- entries, reduce: {state, %{}} do
          {state, refs} ->
            # determine the existence of Credo and memoize the result
            state =
              if not Map.has_key?(state.runtimes, runtime) do
                case Runtime.call(runtime, {Code, :ensure_loaded?, [Credo]}) do
                  {:ok, true} ->
                    :next_ls
                    |> :code.priv_dir()
                    |> Path.join("monkey/_next_ls_private_credo.ex")
                    |> then(&Runtime.call(runtime, {Code, :compile_file, [&1]}))

                    Runtime.call(runtime, {Application, :ensure_all_started, [:credo]})
                    Runtime.call(runtime, {GenServer, :call, [Credo.CLI.Output.Shell, {:suppress_output, true}]})

                    put_in(state.runtimes[runtime], true)

                  _ ->
                    state
                end
              else
                state
              end

            # if runtime has Credo
            if state.runtimes[runtime] do
              namespace = {:credo, path}
              DiagnosticCache.clear(state.cache, namespace)

              task =
                Task.Supervisor.async_nolink(state.task_supervisor, fn ->
                  case Runtime.call(runtime, {:_next_ls_private_credo, :issues, [path]}) do
                    {:ok, issues} -> issues
                    _error -> []
                  end
                end)

              {state, Map.put(refs, task.ref, namespace)}
            else
              {state, refs}
            end
        end
      end)

    send(state.publisher, :publish)

    {:noreply, put_in(state.refresh_refs, refresh_refs)}
  end

  def handle_info({ref, issues}, %{refresh_refs: refs} = state) when is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    {{:credo, path} = namespace, refs} = Map.pop(refs, ref)

    for issue <- issues do
      diagnostic = %Diagnostic{
        range: %Range{
          start: %Position{
            line: issue.line_no - 1,
            character: (issue.column || 1) - 1
          },
          end: %Position{
            line: issue.line_no - 1,
            character: 999
          }
        },
        severity: category_to_severity(issue.category),
        data: %{check: issue.check, file: issue.filename},
        source: "credo",
        code: Macro.to_string(issue.check),
        code_description: %CodeDescription{
          href: "https://hexdocs.pm/credo/#{Macro.to_string(issue.check)}.html"
        },
        message: issue.message
      }

      DiagnosticCache.put(state.cache, namespace, Path.join(path, issue.filename), diagnostic)
    end

    send(state.publisher, :publish)

    {:noreply, put_in(state.refresh_refs, refs)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{refresh_refs: refs} = state) when is_map_key(refs, ref) do
    {_, refs} = Map.pop(refs, ref)

    {:noreply, put_in(state.refresh_refs, refs)}
  end

  defp dispatch(registry, key, callback) do
    ref = make_ref()
    me = self()

    Registry.dispatch(registry, key, fn entries ->
      result = callback.(entries)

      send(me, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    end
  end

  defp category_to_severity(:refactor), do: DiagnosticSeverity.error()
  defp category_to_severity(:warning), do: DiagnosticSeverity.warning()
  defp category_to_severity(:design), do: DiagnosticSeverity.information()

  defp category_to_severity(:consistency), do: DiagnosticSeverity.information()

  defp category_to_severity(:readability), do: DiagnosticSeverity.information()
end
