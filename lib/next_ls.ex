defmodule NextLS do
  @moduledoc false
  use GenLSP

  alias GenLSP.ErrorResponse

  alias GenLSP.Enumerations.{
    ErrorCodes,
    TextDocumentSyncKind
  }

  alias GenLSP.Notifications.{
    Exit,
    Initialized,
    TextDocumentDidChange,
    TextDocumentDidOpen,
    TextDocumentDidSave
  }

  alias GenLSP.Requests.{Initialize, Shutdown}

  alias GenLSP.Structures.{
    DidOpenTextDocumentParams,
    InitializeParams,
    InitializeResult,
    SaveOptions,
    ServerCapabilities,
    TextDocumentItem,
    TextDocumentSyncOptions
  }

  def start_link(args) do
    {args, opts} = Keyword.split(args, [:task_supervisor, :runtime_supervisor])

    GenLSP.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(lsp, args) do
    task_supervisor = Keyword.fetch!(args, :task_supervisor)
    runtime_supervisor = Keyword.fetch!(args, :runtime_supervisor)

    {:ok,
     assign(lsp,
       exit_code: 1,
       documents: %{},
       refresh_refs: %{},
       task_supervisor: task_supervisor,
       runtime_supervisor: runtime_supervisor,
       runtime_task: nil,
       ready: false
     )}
  end

  @impl true
  def handle_request(
        %Initialize{params: %InitializeParams{root_uri: root_uri}},
        lsp
      ) do
    {:reply,
     %InitializeResult{
       capabilities: %ServerCapabilities{
         text_document_sync: %TextDocumentSyncOptions{
           open_close: true,
           save: %SaveOptions{include_text: true},
           change: TextDocumentSyncKind.full()
         }
       },
       server_info: %{name: "NextLS"}
     }, assign(lsp, root_uri: root_uri)}
  end

  def handle_request(%Shutdown{}, lsp) do
    {:reply, nil, assign(lsp, exit_code: 0)}
  end

  def handle_request(%{method: method}, lsp) do
    GenLSP.warning(lsp, "[NextLS] Method Not Found: #{method}")

    {:reply,
     %ErrorResponse{
       code: ErrorCodes.method_not_found(),
       message: "Method Not Found: #{method}"
     }, lsp}
  end

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    GenLSP.log(lsp, "[NextLS] LSP Initialized!")

    working_dir = URI.parse(lsp.assigns.root_uri).path

    GenLSP.log(lsp, "[NextLS] Booting runime...")

    {:ok, runtime} =
      DynamicSupervisor.start_child(
        lsp.assigns.runtime_supervisor,
        {NextLS.Runtime, working_dir: working_dir, parent: self()}
      )

    Process.monitor(runtime)

    lsp = assign(lsp, runtime: runtime)

    task =
      Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
        with false <-
               wait_until(fn ->
                 NextLS.Runtime.ready?(runtime)
               end) do
          GenLSP.error(lsp, "Failed to start runtime")
          raise "Failed to boot runtime"
        end

        GenLSP.log(lsp, "[NextLS] Runtime ready...")

        :ready
      end)

    {:noreply, assign(lsp, runtime_task: task)}
  end

  def handle_notification(%TextDocumentDidSave{}, %{assigns: %{ready: false}} = lsp) do
    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidSave{
          params: %GenLSP.Structures.DidSaveTextDocumentParams{
            text: text,
            text_document: %{uri: uri}
          }
        },
        %{assigns: %{ready: true}} = lsp
      ) do
    {:noreply, lsp |> then(&put_in(&1.assigns.documents[uri], String.split(text, "\n")))}
  end

  def handle_notification(%TextDocumentDidChange{}, %{assigns: %{ready: false}} = lsp) do
    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidChange{}, lsp) do
    for task <- Task.Supervisor.children(lsp.assigns.task_supervisor),
        task != lsp.assigns.runtime_task do
      Process.exit(task, :kill)
    end

    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidOpen{
          params: %DidOpenTextDocumentParams{
            text_document: %TextDocumentItem{text: text, uri: uri}
          }
        },
        lsp
      ) do
    {:noreply, put_in(lsp.assigns.documents[uri], String.split(text, "\n"))}
  end

  def handle_notification(%Exit{}, lsp) do
    System.halt(lsp.assigns.exit_code)

    {:noreply, lsp}
  end

  def handle_notification(_notification, lsp) do
    {:noreply, lsp}
  end

  def handle_info({ref, resp}, %{assigns: %{refresh_refs: refs}} = lsp)
      when is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    {_token, refs} = Map.pop(refs, ref)

    lsp =
      case resp do
        :ready ->
          assign(lsp, ready: true)

        _ ->
          lsp
      end

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %{assigns: %{refresh_refs: refs}} = lsp
      )
      when is_map_key(refs, ref) do
    {_token, refs} = Map.pop(refs, ref)

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info(
        {:DOWN, _ref, :process, runtime, _reason},
        %{assigns: %{runtime: runtime}} = lsp
      ) do
    GenLSP.error(lsp, "[NextLS] The runtime has crashed")

    {:noreply, assign(lsp, runtime: nil)}
  end

  def handle_info({:log, message}, lsp) do
    GenLSP.log(lsp, String.trim(message))

    {:noreply, lsp}
  end

  def handle_info(_, lsp) do
    {:noreply, lsp}
  end

  defp wait_until(cb) do
    wait_until(120, cb)
  end

  defp wait_until(0, _cb) do
    false
  end

  defp wait_until(n, cb) do
    if cb.() do
      true
    else
      Process.sleep(1000)
      wait_until(n - 1, cb)
    end
  end
end
