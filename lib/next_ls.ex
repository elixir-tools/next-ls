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

  alias GenLSP.Requests.{
    Initialize,
    Shutdown,
    TextDocumentFormatting
  }

  alias GenLSP.Structures.{
    DidOpenTextDocumentParams,
    InitializeParams,
    InitializeResult,
    Position,
    Range,
    SaveOptions,
    ServerCapabilities,
    TextDocumentItem,
    TextDocumentSyncOptions,
    TextEdit
  }

  alias NextLS.Runtime
  alias NextLS.DiagnosticCache

  def start_link(args) do
    {args, opts} =
      Keyword.split(args, [
        :cache,
        :task_supervisor,
        :dynamic_supervisor,
        :extensions,
        :extension_registry
      ])

    GenLSP.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(lsp, args) do
    task_supervisor = Keyword.fetch!(args, :task_supervisor)
    dynamic_supervisor = Keyword.fetch!(args, :dynamic_supervisor)
    extension_registry = Keyword.fetch!(args, :extension_registry)
    extensions = Keyword.get(args, :extensions, [NextLS.ElixirExtension])
    cache = Keyword.fetch!(args, :cache)

    {:ok,
     assign(lsp,
       exit_code: 1,
       documents: %{},
       refresh_refs: %{},
       cache: cache,
       task_supervisor: task_supervisor,
       dynamic_supervisor: dynamic_supervisor,
       extension_registry: extension_registry,
       extensions: extensions,
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
         },
         document_formatting_provider: true
       },
       server_info: %{name: "NextLS"}
     }, assign(lsp, root_uri: root_uri)}
  end

  def handle_request(%TextDocumentFormatting{params: %{text_document: %{uri: uri}}}, lsp) do
    document = lsp.assigns.documents[uri]

    working_dir = URI.parse(lsp.assigns.root_uri).path
    {opts, _} = Code.eval_file(".formatter.exs", working_dir)
    new_document = Code.format_string!(Enum.join(document, "\n"), opts) |> IO.iodata_to_binary()

    {:reply,
     [
       %TextEdit{
         new_text: new_document,
         range: %Range{
           start: %Position{line: 0, character: 0},
           end: %Position{
             line: length(document),
             character: document |> List.last() |> String.length() |> Kernel.-(1) |> max(0)
           }
         }
       }
     ], lsp}
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

    for extension <- lsp.assigns.extensions do
      {:ok, _} =
        DynamicSupervisor.start_child(
          lsp.assigns.dynamic_supervisor,
          {extension, cache: lsp.assigns.cache, registry: lsp.assigns.extension_registry, publisher: self()}
        )
    end

    GenLSP.log(lsp, "[NextLS] Booting runime...")

    {:ok, runtime} =
      DynamicSupervisor.start_child(
        lsp.assigns.dynamic_supervisor,
        {NextLS.Runtime, extension_registry: lsp.assigns.extension_registry, working_dir: working_dir, parent: self()}
      )

    Process.monitor(runtime)

    lsp = assign(lsp, runtime: runtime)

    task =
      Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
        with false <-
               wait_until(fn ->
                 NextLS.Runtime.ready?(runtime)
               end) do
          GenLSP.error(lsp, "[NextLS] Failed to start runtime")
          raise "Failed to boot runtime"
        end

        GenLSP.log(lsp, "[NextLS] Runtime ready...")

        :ready
      end)

    {:noreply, assign(lsp, refresh_refs: Map.put(lsp.assigns.refresh_refs, task.ref, task.ref), runtime_task: task)}
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
    task =
      Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
        Runtime.compile(lsp.assigns.runtime)
      end)

    {:noreply,
     lsp
     |> then(&put_in(&1.assigns.documents[uri], String.split(text, "\n")))
     |> then(&put_in(&1.assigns.refresh_refs[task.ref], task.ref))}
  end

  def handle_notification(%TextDocumentDidChange{}, %{assigns: %{ready: false}} = lsp) do
    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidChange{
          params: %{
            text_document: %{uri: uri},
            content_changes: [%{text: text}]
          }
        },
        lsp
      ) do
    for task <- Task.Supervisor.children(lsp.assigns.task_supervisor),
        task != lsp.assigns.runtime_task.pid do
      Process.exit(task, :kill)
    end

    {:noreply, put_in(lsp.assigns.documents[uri], String.split(text, "\n"))}
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

  def handle_info(:publish, lsp) do
    all =
      for {_namespace, cache} <- DiagnosticCache.get(lsp.assigns.cache), {file, diagnostics} <- cache, reduce: %{} do
        d -> Map.update(d, file, diagnostics, fn value -> value ++ diagnostics end)
      end

    for {file, diagnostics} <- all do
      GenLSP.notify(lsp, %GenLSP.Notifications.TextDocumentPublishDiagnostics{
        params: %GenLSP.Structures.PublishDiagnosticsParams{
          uri: "file://#{file}",
          diagnostics: diagnostics
        }
      })
    end

    {:noreply, lsp}
  end

  def handle_info({ref, resp}, %{assigns: %{refresh_refs: refs}} = lsp)
      when is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    {_token, refs} = Map.pop(refs, ref)

    lsp =
      case resp do
        :ready ->
          task =
            Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
              Runtime.compile(lsp.assigns.runtime)
            end)

          assign(lsp, ready: true, refresh_refs: Map.put(refs, task.ref, task.ref))

        _ ->
          assign(lsp, refresh_refs: refs)
      end

    {:noreply, lsp}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{assigns: %{refresh_refs: refs}} = lsp)
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
    GenLSP.log(lsp, "[NextLS] " <> String.trim(message))

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
