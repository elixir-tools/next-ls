defmodule NextLS do
  @moduledoc false
  use GenLSP

  alias GenLSP.Enumerations.ErrorCodes
  alias GenLSP.Enumerations.TextDocumentSyncKind
  alias GenLSP.ErrorResponse
  alias GenLSP.Notifications.Exit
  alias GenLSP.Notifications.Initialized
  alias GenLSP.Notifications.TextDocumentDidChange
  alias GenLSP.Notifications.TextDocumentDidOpen
  alias GenLSP.Notifications.TextDocumentDidSave
  alias GenLSP.Notifications.WorkspaceDidChangeWatchedFiles
  alias GenLSP.Notifications.WorkspaceDidChangeWorkspaceFolders
  alias GenLSP.Requests.Initialize
  alias GenLSP.Requests.Shutdown
  alias GenLSP.Requests.TextDocumentDefinition
  alias GenLSP.Requests.TextDocumentDocumentSymbol
  alias GenLSP.Requests.TextDocumentFormatting
  alias GenLSP.Requests.WorkspaceSymbol
  alias GenLSP.Structures.DidChangeWatchedFilesParams
  alias GenLSP.Structures.DidChangeWorkspaceFoldersParams
  alias GenLSP.Structures.DidOpenTextDocumentParams
  alias GenLSP.Structures.InitializeParams
  alias GenLSP.Structures.InitializeResult
  alias GenLSP.Structures.Location
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.SaveOptions
  alias GenLSP.Structures.ServerCapabilities
  alias GenLSP.Structures.SymbolInformation
  alias GenLSP.Structures.TextDocumentItem
  alias GenLSP.Structures.TextDocumentSyncOptions
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceFoldersChangeEvent
  alias NextLS.Definition
  alias NextLS.DiagnosticCache
  alias NextLS.Progress
  alias NextLS.Runtime
  alias NextLS.SymbolTable

  def start_link(args) do
    {args, opts} =
      Keyword.split(args, [
        :cache,
        :task_supervisor,
        :runtime_task_supervisor,
        :dynamic_supervisor,
        :extensions,
        :registry
      ])

    GenLSP.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(lsp, args) do
    task_supervisor = Keyword.fetch!(args, :task_supervisor)
    runtime_task_supervisor = Keyword.fetch!(args, :runtime_task_supervisor)
    dynamic_supervisor = Keyword.fetch!(args, :dynamic_supervisor)

    registry = Keyword.fetch!(args, :registry)
    extensions = Keyword.get(args, :extensions, [NextLS.ElixirExtension])
    cache = Keyword.fetch!(args, :cache)
    {:ok, logger} = DynamicSupervisor.start_child(dynamic_supervisor, {NextLS.Logger, lsp: lsp})

    {:ok,
     assign(lsp,
       exit_code: 1,
       documents: %{},
       refresh_refs: %{},
       cache: cache,
       logger: logger,
       task_supervisor: task_supervisor,
       runtime_task_supervisor: runtime_task_supervisor,
       dynamic_supervisor: dynamic_supervisor,
       registry: registry,
       extensions: extensions,
       ready: false,
       client_capabilities: nil
     )}
  end

  @impl true
  def handle_request(
        %Initialize{
          params: %InitializeParams{root_uri: root_uri, workspace_folders: workspace_folders, capabilities: caps}
        },
        lsp
      ) do
    workspace_folders =
      if caps.workspace.workspace_folders do
        workspace_folders
      else
        %{name: Path.basename(root_uri), uri: root_uri}
      end

    {:reply,
     %InitializeResult{
       capabilities: %ServerCapabilities{
         text_document_sync: %TextDocumentSyncOptions{
           open_close: true,
           save: %SaveOptions{include_text: true},
           change: TextDocumentSyncKind.full()
         },
         document_formatting_provider: true,
         workspace_symbol_provider: true,
         document_symbol_provider: true,
         definition_provider: true,
         workspace: %{
           workspace_folders: %GenLSP.Structures.WorkspaceFoldersServerCapabilities{
             supported: true,
             change_notifications: true
           }
         }
       },
       server_info: %{name: "Next LS"}
     }, assign(lsp, root_uri: root_uri, workspace_folders: workspace_folders, client_capabilities: caps)}
  end

  def handle_request(%TextDocumentDefinition{params: %{text_document: %{uri: uri}, position: position}}, lsp) do
    result =
      dispatch(lsp.assigns.registry, :symbol_tables, fn entries ->
        for {_, %{symbol_table: symbol_table, reference_table: ref_table}} <- entries do
          case Definition.fetch(
                 URI.parse(uri).path,
                 {position.line + 1, position.character + 1},
                 symbol_table,
                 ref_table
               ) do
            nil ->
              nil

            [] ->
              nil

            [{file, line, column} | _] ->
              %Location{
                uri: "file://#{file}",
                range: %Range{
                  start: %Position{
                    line: line - 1,
                    character: column - 1
                  },
                  end: %Position{
                    line: line - 1,
                    character: column - 1
                  }
                }
              }
          end
        end
      end)

    {:reply, List.first(result), lsp}
  end

  def handle_request(%TextDocumentDocumentSymbol{params: %{text_document: %{uri: uri}}}, lsp) do
    symbols =
      try do
        lsp.assigns.documents[uri]
        |> Enum.join("\n")
        |> NextLS.DocumentSymbol.fetch()
      rescue
        e ->
          GenLSP.error(lsp, Exception.format_banner(:error, e, __STACKTRACE__))
          nil
      end

    {:reply, symbols, lsp}
  end

  def handle_request(%WorkspaceSymbol{params: %{query: query}}, lsp) do
    filter = fn sym ->
      if query == "" do
        true
      else
        to_string(sym) =~ query
      end
    end

    symbols =
      dispatch(lsp.assigns.registry, :symbol_tables, fn entries ->
        for {pid, _} <- entries, %SymbolTable.Symbol{} = symbol <- SymbolTable.symbols(pid), filter.(symbol.name) do
          name =
            if symbol.type != :defstruct do
              "#{symbol.type} #{symbol.name}"
            else
              "#{symbol.name}"
            end

          %SymbolInformation{
            name: name,
            kind: elixir_kind_to_lsp_kind(symbol.type),
            location: %Location{
              uri: "file://#{symbol.file}",
              range: %Range{
                start: %Position{
                  line: symbol.line - 1,
                  character: symbol.col - 1
                },
                end: %Position{
                  line: symbol.line - 1,
                  character: symbol.col - 1
                }
              }
            }
          }
        end
      end)

    {:reply, symbols, lsp}
  end

  def handle_request(%TextDocumentFormatting{params: %{text_document: %{uri: uri}}}, lsp) do
    document = lsp.assigns.documents[uri]

    [resp] =
      dispatch(lsp.assigns.registry, :runtimes, fn entries ->
        for {runtime, %{uri: wuri}} <- entries, String.starts_with?(uri, wuri) do
          with {:ok, {formatter, _}} <-
                 Runtime.call(runtime, {Mix.Tasks.Format, :formatter_for_file, [".formatter.exs"]}),
               {:ok, response} when is_binary(response) or is_list(response) <-
                 Runtime.call(runtime, {Kernel, :apply, [formatter, [Enum.join(document, "\n")]]}) do
            {:reply,
             [
               %TextEdit{
                 new_text: IO.iodata_to_binary(response),
                 range: %Range{
                   start: %Position{line: 0, character: 0},
                   end: %Position{
                     line: length(document),
                     character: document |> List.last() |> String.length() |> Kernel.-(1) |> max(0)
                   }
                 }
               }
             ], lsp}
          else
            {:error, :not_ready} ->
              GenLSP.notify(lsp, %GenLSP.Notifications.WindowShowMessage{
                params: %GenLSP.Structures.ShowMessageParams{
                  type: GenLSP.Enumerations.MessageType.info(),
                  message: "The NextLS runtime is still initializing!"
                }
              })

              {:reply, nil, lsp}

            _ ->
              {:reply, nil, lsp}
          end
        end
      end)

    resp
  end

  def handle_request(%Shutdown{}, lsp) do
    dispatch(lsp.assigns.registry, :symbol_tables, fn entries ->
      for {pid, _} <- entries, do: SymbolTable.close(pid)
    end)

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
    GenLSP.log(lsp, "[NextLS] NextLS v#{version()} has initialized!")

    for extension <- lsp.assigns.extensions do
      {:ok, _} =
        DynamicSupervisor.start_child(
          lsp.assigns.dynamic_supervisor,
          {extension, cache: lsp.assigns.cache, registry: lsp.assigns.registry, publisher: self()}
        )
    end

    nil =
      GenLSP.request(lsp, %GenLSP.Requests.ClientRegisterCapability{
        id: System.unique_integer([:positive]),
        params: %GenLSP.Structures.RegistrationParams{
          registrations: [
            %GenLSP.Structures.Registration{
              id: "file-watching",
              method: "workspace/didChangeWatchedFiles",
              register_options: %GenLSP.Structures.DidChangeWatchedFilesRegistrationOptions{
                watchers:
                  for ext <- ~W|ex exs leex eex heex sface| do
                    %GenLSP.Structures.FileSystemWatcher{kind: 7, glob_pattern: "**/*.#{ext}"}
                  end
              }
            }
          ]
        }
      })

    GenLSP.log(lsp, "[NextLS] Booting runtimes...")

    for %{uri: uri, name: name} <- lsp.assigns.workspace_folders do
      token = token()
      Progress.start(lsp, token, "Initializing NextLS runtime for folder #{name}...")
      parent = self()
      working_dir = URI.parse(uri).path

      {:ok, _} =
        DynamicSupervisor.start_child(
          lsp.assigns.dynamic_supervisor,
          {NextLS.Runtime.Supervisor,
           path: Path.join(working_dir, ".elixir-tools"),
           name: name,
           registry: lsp.assigns.registry,
           runtime: [
             task_supervisor: lsp.assigns.runtime_task_supervisor,
             working_dir: working_dir,
             uri: uri,
             on_initialized: fn status ->
               if status == :ready do
                 Progress.stop(lsp, token, "NextLS runtime for folder #{name} has initialized!")
                 GenLSP.log(lsp, "[NextLS] Runtime for folder #{name} is ready...")
                 send(parent, {:runtime_ready, name, self()})
               else
                 Progress.stop(lsp, token)
                 GenLSP.error(lsp, "[NextLS] Runtime for folder #{name} failed to initialize")
               end
             end,
             logger: lsp.assigns.logger
           ]}
        )
    end

    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidSave{}, %{assigns: %{ready: false}} = lsp) do
    {:noreply, lsp}
  end

  # TODO: add some test cases for saving files in multiple workspaces
  def handle_notification(
        %TextDocumentDidSave{
          params: %GenLSP.Structures.DidSaveTextDocumentParams{text: text, text_document: %{uri: uri}}
        },
        %{assigns: %{ready: true}} = lsp
      ) do
    for task <- Task.Supervisor.children(lsp.assigns.task_supervisor) do
      Process.exit(task, :kill)
    end

    refresh_refs =
      dispatch(lsp.assigns.registry, :runtimes, fn entries ->
        for {pid, %{name: name, uri: wuri}} <- entries, String.starts_with?(uri, wuri), into: %{} do
          token = token()
          Progress.start(lsp, token, "Compiling...")

          task =
            Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
              {name, Runtime.compile(pid)}
            end)

          {task.ref, {token, "Compiled!"}}
        end
      end)

    {:noreply,
     lsp
     |> then(&put_in(&1.assigns.documents[uri], String.split(text, "\n")))
     |> then(&put_in(&1.assigns.refresh_refs, refresh_refs))}
  end

  def handle_notification(%TextDocumentDidChange{}, %{assigns: %{ready: false}} = lsp) do
    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidChange{params: %{text_document: %{uri: uri}, content_changes: [%{text: text}]}},
        lsp
      ) do
    for task <- Task.Supervisor.children(lsp.assigns.task_supervisor) do
      Process.exit(task, :kill)
    end

    {:noreply, put_in(lsp.assigns.documents[uri], String.split(text, "\n"))}
  end

  def handle_notification(
        %TextDocumentDidOpen{
          params: %DidOpenTextDocumentParams{text_document: %TextDocumentItem{text: text, uri: uri}}
        },
        lsp
      ) do
    {:noreply, put_in(lsp.assigns.documents[uri], String.split(text, "\n"))}
  end

  def handle_notification(
        %WorkspaceDidChangeWorkspaceFolders{
          params: %DidChangeWorkspaceFoldersParams{event: %WorkspaceFoldersChangeEvent{added: added, removed: removed}}
        },
        lsp
      ) do
    dispatch(lsp.assigns.registry, :runtime_supervisors, fn entries ->
      names = Enum.map(entries, fn {_, %{name: name}} -> name end)

      for %{name: name, uri: uri} <- added, name not in names do
        GenLSP.log(lsp, "[NextLS] Adding workspace folder #{name}")
        token = token()
        Progress.start(lsp, token, "Initializing NextLS runtime for folder #{name}...")
        parent = self()
        working_dir = URI.parse(uri).path

        # TODO: probably extract this to the Runtime module
        {:ok, _} =
          DynamicSupervisor.start_child(
            lsp.assigns.dynamic_supervisor,
            {NextLS.Runtime.Supervisor,
             path: Path.join(working_dir, ".elixir-tools"),
             name: name,
             registry: lsp.assigns.registry,
             runtime: [
               task_supervisor: lsp.assigns.runtime_task_supervisor,
               working_dir: working_dir,
               uri: uri,
               on_initialized: fn status ->
                 if status == :ready do
                   Progress.stop(lsp, token, "NextLS runtime for folder #{name} has initialized!")
                   GenLSP.log(lsp, "[NextLS] Runtime for folder #{name} is ready...")
                   send(parent, {:runtime_ready, name, self()})
                 else
                   Progress.stop(lsp, token)
                   GenLSP.error(lsp, "[NextLS] Runtime for folder #{name} failed to initialize")
                 end
               end,
               logger: lsp.assigns.logger
             ]}
          )
      end

      names = Enum.map(removed, & &1.name)

      for {pid, %{name: name}} <- entries, name in names do
        GenLSP.log(lsp, "[NextLS] Removing workspace folder #{name}")
        # TODO: probably extract this to the Runtime module
        DynamicSupervisor.terminate_child(lsp.assigns.dynamic_supervisor, pid)
      end
    end)

    {:noreply, lsp}
  end

  def handle_notification(%WorkspaceDidChangeWatchedFiles{params: %DidChangeWatchedFilesParams{changes: changes}}, lsp) do
    type = GenLSP.Enumerations.FileChangeType.deleted()

    # TODO
    # ✅ delete from documents
    # ✅ delete all references that occur in this file
    # ✅ delete all symbols from that file
    lsp =
      for %{type: ^type, uri: uri} <- changes, reduce: lsp do
        lsp ->
          dispatch(lsp.assigns.registry, :symbol_tables, fn entries ->
            for {pid, _} <- entries do
              SymbolTable.remove(pid, uri)
            end
          end)

          update_in(lsp.assigns.documents, &Map.drop(&1, [uri]))
      end

    {:noreply, lsp}
  end

  def handle_notification(%Exit{}, lsp) do
    System.halt(lsp.assigns.exit_code)

    {:noreply, lsp}
  end

  def handle_notification(_notification, lsp) do
    {:noreply, lsp}
  end

  def handle_info(:publish, lsp) do
    GenLSP.log(lsp, "[NextLS] Compiled!")

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

  def handle_info({:runtime_ready, name, runtime_pid}, lsp) do
    token = token()
    Progress.start(lsp, token, "Compiling...")

    task =
      Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
        {name, Runtime.compile(runtime_pid)}
      end)

    refresh_refs = Map.put(lsp.assigns.refresh_refs, task.ref, {token, "Compiled!"})

    {:noreply, assign(lsp, ready: true, refresh_refs: refresh_refs)}
  end

  def handle_info({ref, _resp}, %{assigns: %{refresh_refs: refs}} = lsp) when is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    {{token, msg}, refs} = Map.pop(refs, ref)

    Progress.stop(lsp, token, msg)

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{assigns: %{refresh_refs: refs}} = lsp)
      when is_map_key(refs, ref) do
    {{token, _}, refs} = Map.pop(refs, ref)

    Progress.stop(lsp, token)

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info(message, lsp) do
    GenLSP.log(lsp, "[NextLS] Unhandled message: #{inspect(message)}")
    {:noreply, lsp}
  end

  defp token do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end

  defp version do
    case :application.get_key(:next_ls, :vsn) do
      {:ok, version} -> to_string(version)
      _ -> "dev"
    end
  end

  defp elixir_kind_to_lsp_kind(:defmodule), do: GenLSP.Enumerations.SymbolKind.module()
  defp elixir_kind_to_lsp_kind(:defstruct), do: GenLSP.Enumerations.SymbolKind.struct()

  defp elixir_kind_to_lsp_kind(kind) when kind in [:def, :defp, :defmacro, :defmacrop],
    do: GenLSP.Enumerations.SymbolKind.function()

  # NOTE: this is only possible because the registry is not partitioned
  # if it is partitioned, then the callback is called multiple times
  # and this method of extracting the result doesn't really make sense
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
end
