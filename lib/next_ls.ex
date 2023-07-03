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
    TextDocumentDocumentSymbol,
    TextDocumentDefinition,
    TextDocumentFormatting,
    WorkspaceSymbol
  }

  alias GenLSP.Structures.{
    DidOpenTextDocumentParams,
    InitializeParams,
    InitializeResult,
    Location,
    Position,
    Range,
    SaveOptions,
    ServerCapabilities,
    SymbolInformation,
    TextDocumentItem,
    TextDocumentSyncOptions,
    TextEdit,
    WorkDoneProgressBegin,
    WorkDoneProgressEnd
  }

  alias NextLS.DiagnosticCache
  alias NextLS.Runtime
  alias NextLS.SymbolTable
  alias NextLS.Definition

  def start_link(args) do
    {args, opts} =
      Keyword.split(args, [
        :cache,
        :task_supervisor,
        :dynamic_supervisor,
        :extensions,
        :extension_registry,
        :symbol_table
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
    symbol_table = Keyword.fetch!(args, :symbol_table)

    {:ok,
     assign(lsp,
       exit_code: 1,
       documents: %{},
       refresh_refs: %{},
       cache: cache,
       symbol_table: symbol_table,
       task_supervisor: task_supervisor,
       dynamic_supervisor: dynamic_supervisor,
       extension_registry: extension_registry,
       extensions: extensions,
       runtime_task: nil,
       ready: false
     )}
  end

  @impl true
  def handle_request(%Initialize{params: %InitializeParams{root_uri: root_uri}}, lsp) do
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
         definition_provider: true
       },
       server_info: %{name: "NextLS"}
     }, assign(lsp, root_uri: root_uri)}
  end

  def handle_request(%TextDocumentDefinition{params: %{text_document: %{uri: uri}, position: position}}, lsp) do
    result =
      case Definition.fetch(
             URI.parse(uri).path,
             {position.line + 1, position.character + 1},
             :symbol_table,
             :reference_table
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

    {:reply, result, lsp}
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
      for %SymbolTable.Symbol{} = symbol <- SymbolTable.symbols(lsp.assigns.symbol_table), filter.(symbol.name) do
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

    {:reply, symbols, lsp}
  end

  def handle_request(%TextDocumentFormatting{params: %{text_document: %{uri: uri}}}, lsp) do
    document = lsp.assigns.documents[uri]
    runtime = lsp.assigns.runtime

    with {:ok, {formatter, _}} <- Runtime.call(runtime, {Mix.Tasks.Format, :formatter_for_file, [".formatter.exs"]}),
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

  def handle_request(%Shutdown{}, lsp) do
    SymbolTable.close(lsp.assigns.symbol_table)

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

    working_dir = URI.parse(lsp.assigns.root_uri).path

    for extension <- lsp.assigns.extensions do
      {:ok, _} =
        DynamicSupervisor.start_child(
          lsp.assigns.dynamic_supervisor,
          {extension, cache: lsp.assigns.cache, registry: lsp.assigns.extension_registry, publisher: self()}
        )
    end

    GenLSP.log(lsp, "[NextLS] Booting runime...")

    token = token()

    progress_start(lsp, token, "Initializing NextLS runtime...")

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

    {:noreply,
     assign(lsp,
       refresh_refs: Map.put(lsp.assigns.refresh_refs, task.ref, {token, "NextLS runtime has initialized!"}),
       runtime_task: task
     )}
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
    for task <- Task.Supervisor.children(lsp.assigns.task_supervisor),
        task != lsp.assigns.runtime_task.pid do
      Process.exit(task, :kill)
    end

    token = token()

    progress_start(lsp, token, "Compiling...")

    task =
      Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
        Runtime.compile(lsp.assigns.runtime)
      end)

    {:noreply,
     lsp
     |> then(&put_in(&1.assigns.documents[uri], String.split(text, "\n")))
     |> then(&put_in(&1.assigns.refresh_refs[task.ref], {token, "Compiled!"}))}
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

  def handle_info({:tracer, payload}, lsp) do
    SymbolTable.put_symbols(lsp.assigns.symbol_table, payload)
    {:noreply, lsp}
  end

  def handle_info({{:tracer, :reference}, payload}, lsp) do
    SymbolTable.put_reference(lsp.assigns.symbol_table, payload)
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

  def handle_info({ref, resp}, %{assigns: %{refresh_refs: refs}} = lsp) when is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    {{token, msg}, refs} = Map.pop(refs, ref)

    progress_end(lsp, token, msg)

    lsp =
      case resp do
        :ready ->
          token = token()
          progress_start(lsp, token, "Compiling...")

          task =
            Task.Supervisor.async_nolink(lsp.assigns.task_supervisor, fn ->
              Runtime.compile(lsp.assigns.runtime)
            end)

          assign(lsp, ready: true, refresh_refs: Map.put(refs, task.ref, {token, "Compiled!"}))

        _ ->
          assign(lsp, refresh_refs: refs)
      end

    {:noreply, lsp}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{assigns: %{refresh_refs: refs}} = lsp)
      when is_map_key(refs, ref) do
    {{token, _}, refs} = Map.pop(refs, ref)

    progress_end(lsp, token)

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

  def handle_info(message, lsp) do
    GenLSP.log(lsp, "[NextLS] Unhanded message: #{inspect(message)}")
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

  defp progress_start(lsp, token, msg) do
    GenLSP.notify(lsp, %GenLSP.Notifications.DollarProgress{
      params: %GenLSP.Structures.ProgressParams{
        token: token,
        value: %WorkDoneProgressBegin{
          kind: "begin",
          title: msg
        }
      }
    })
  end

  defp progress_end(lsp, token, msg \\ nil) do
    GenLSP.notify(lsp, %GenLSP.Notifications.DollarProgress{
      params: %GenLSP.Structures.ProgressParams{
        token: token,
        value: %WorkDoneProgressEnd{
          kind: "end",
          message: msg
        }
      }
    })
  end

  defp token() do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end

  defp version() do
    case :application.get_key(:next_ls, :vsn) do
      {:ok, version} -> to_string(version)
      _ -> "dev"
    end
  end

  defp elixir_kind_to_lsp_kind(:defmodule), do: GenLSP.Enumerations.SymbolKind.module()
  defp elixir_kind_to_lsp_kind(:defstruct), do: GenLSP.Enumerations.SymbolKind.struct()

  defp elixir_kind_to_lsp_kind(kind) when kind in [:def, :defp, :defmacro, :defmacrop],
    do: GenLSP.Enumerations.SymbolKind.function()
end
