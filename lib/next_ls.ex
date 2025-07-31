defmodule NextLS do
  @moduledoc false
  use GenLSP
  use NextLS.Aliases

  import NextLS.DB.Query

  alias NextLS.ASTHelpers.Variables
  alias NextLS.Commands.Pipe
  alias NextLS.DB
  alias NextLS.Definition
  alias NextLS.DiagnosticCache
  alias NextLS.Progress
  alias NextLS.Runtime
  alias NextLS.Runtime.BundledElixir

  require NextLS.Runtime

  def start_link(args) do
    {args, opts} =
      Keyword.split(args, [
        :cache,
        :auto_update,
        :runtime_task_supervisor,
        :dynamic_supervisor,
        :extensions,
        :registry,
        :bundle_base,
        :mix_home,
        :mix_archives
      ])

    GenLSP.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(lsp, args) do
    runtime_task_supervisor = Keyword.fetch!(args, :runtime_task_supervisor)
    dynamic_supervisor = Keyword.fetch!(args, :dynamic_supervisor)
    bundle_base = Keyword.get(args, :bundle_base, Path.expand("~/.cache/elixir-tools/nextls"))
    mix_home = Keyword.get(args, :mix_home)
    mix_archives = Keyword.get(args, :mix_archives)

    is_1_17 =
      with {version, 0} <- System.cmd("elixir", ["--short-version"]),
           {:ok, version} <- version |> String.trim() |> Version.parse() do
        Version.compare(version, "1.17.0") in [:gt, :eq]
      else
        _ ->
          false
      end

    registry = Keyword.fetch!(args, :registry)

    extensions =
      Keyword.get(args, :extensions, elixir: NextLS.ElixirExtension, credo: NextLS.CredoExtension)

    cache = Keyword.fetch!(args, :cache)
    {:ok, logger} = DynamicSupervisor.start_child(dynamic_supervisor, {NextLS.Logger, lsp: lsp})

    {:ok,
     assign(lsp,
       auto_update: Keyword.get(args, :auto_update, false),
       bundle_base: bundle_base,
       mix_home: mix_home,
       mix_archives: mix_archives,
       is_1_17: is_1_17,
       exit_code: 1,
       documents: %{},
       refresh_refs: %{},
       cache: cache,
       logger: logger,
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
          params: %InitializeParams{
            root_uri: root_uri,
            workspace_folders: workspace_folders,
            capabilities: caps,
            initialization_options: init_opts
          }
        },
        lsp
      ) do
    workspace_folders =
      if caps.workspace.workspace_folders do
        workspace_folders
      else
        [%{name: Path.basename(root_uri), uri: root_uri}]
      end

    {:ok, init_opts} = __MODULE__.InitOpts.validate(init_opts)

    # if we are on 1.17, we will not bundle
    {mix_home, mix_archives} =
      if assigns(lsp).is_1_17 do
        {nil, nil}
      else
        # if we are not on 1.17, we bundle if completions are enabled
        if init_opts.experimental.completions.enable do
          {BundledElixir.mix_home(assigns(lsp).bundle_base), BundledElixir.mix_archives(assigns(lsp).bundle_base)}
        else
          {nil, nil}
        end
      end

    {:reply,
     %InitializeResult{
       capabilities: %ServerCapabilities{
         text_document_sync: %TextDocumentSyncOptions{
           open_close: true,
           save: %SaveOptions{include_text: true},
           change: TextDocumentSyncKind.full()
         },
         code_action_provider: %CodeActionOptions{
           code_action_kinds: [CodeActionKind.quick_fix()]
         },
         completion_provider:
           if init_opts.experimental.completions.enable do
             %GenLSP.Structures.CompletionOptions{
               trigger_characters: [".", "@", "%", "^", ":", "!", "-", "~", "/", "{"],
               resolve_provider: true
             }
           end,
         document_formatting_provider: true,
         execute_command_provider: %GenLSP.Structures.ExecuteCommandOptions{
           commands: [
             "to-pipe",
             "from-pipe",
             "alias-refactor"
           ]
         },
         hover_provider: true,
         workspace_symbol_provider: true,
         document_symbol_provider: true,
         references_provider: true,
         definition_provider: true,
         workspace: %{
           workspace_folders: %GenLSP.Structures.WorkspaceFoldersServerCapabilities{
             supported: true,
             change_notifications: true
           }
         }
       },
       server_info: %{name: "Next LS"}
     },
     assign(lsp,
       mix_home: mix_home,
       mix_archives: mix_archives,
       root_uri: root_uri,
       workspace_folders: workspace_folders,
       client_capabilities: caps,
       init_opts: init_opts
     )}
  end

  def handle_request(
        %TextDocumentCodeAction{
          params: %CodeActionParams{
            context: %CodeActionContext{diagnostics: diagnostics},
            text_document: %TextDocumentIdentifier{uri: uri}
          }
        },
        lsp
      ) do
    code_actions =
      for %Diagnostic{} = diagnostic <- diagnostics,
          data = %NextLS.CodeActionable.Data{
            diagnostic: diagnostic,
            uri: uri,
            document: assigns(lsp).documents[uri]
          },
          namespace = diagnostic.data["namespace"],
          action <- NextLS.CodeActionable.from(namespace, data) do
        action
      end

    {:reply, code_actions, lsp}
  end

  def handle_request(%TextDocumentDefinition{params: %{text_document: %{uri: uri}, position: position}}, lsp) do
    result =
      dispatch(assigns(lsp).registry, :databases, fn entries ->
        for {pid, _} <- entries do
          case Definition.fetch(
                 URI.parse(uri).path,
                 {position.line + 1, position.character + 1},
                 pid
               ) do
            nil ->
              case Variables.get_variable_definition(URI.parse(uri).path, {position.line + 1, position.character + 1}) do
                {_name, {startl..endl//_, startc..endc//_}} ->
                  %Location{
                    uri: "file://#{URI.parse(uri).path}",
                    range: %Range{
                      start: %Position{
                        line: startl - 1,
                        character: startc - 1
                      },
                      end: %Position{
                        line: endl - 1,
                        character: endc - 1
                      }
                    }
                  }

                _other ->
                  nil
              end

            [] ->
              nil

            [[_pk, _mod, file, _type, _name, _params, line, column | _] | _] ->
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

    {:reply, List.first(Enum.reject(result, &is_nil/1)), lsp}
  end

  def handle_request(%TextDocumentDocumentSymbol{params: %{text_document: %{uri: uri}}}, lsp) do
    symbols =
      if Path.extname(uri) in [".ex", ".exs"] && assigns(lsp).documents[uri] do
        try do
          assigns(lsp).documents[uri]
          |> Enum.join("\n")
          |> NextLS.DocumentSymbol.fetch()
        rescue
          e ->
            GenLSP.error(lsp, Exception.format(:error, e, __STACKTRACE__))
            nil
        end
      end

    {:reply, symbols, lsp}
  end

  # TODO handle `context: %{includeDeclaration: true}` to include the current symbol definition among
  # the results.
  def handle_request(%TextDocumentReferences{params: %{position: position, text_document: %{uri: uri}}}, lsp) do
    file = URI.parse(uri).path
    line = position.line + 1
    col = position.character + 1

    locations =
      dispatch(assigns(lsp).registry, :databases, fn databases ->
        Enum.flat_map(databases, fn {database, _} ->
          references =
            case symbol_info(file, line, col, database) do
              {:function, module, function} ->
                DB.query(
                  database,
                  ~Q"""
                  SELECT file, start_line, end_line, start_column, end_column
                  FROM "references" as refs
                  WHERE refs.identifier = ?
                    AND refs.type = ?
                    AND refs.module = ?
                    AND refs.source = 'user'
                  """,
                  [function, "function", module]
                )

              {:module, module} ->
                DB.query(
                  database,
                  ~Q"""
                  SELECT file, start_line, end_line, start_column, end_column
                  FROM "references" as refs
                  WHERE refs.module = ?
                    AND refs.type = ?
                    AND refs.source = 'user'
                  """,
                  [module, "alias"]
                )

              {:attribute, module, attribute} ->
                DB.query(
                  database,
                  ~Q"""
                  SELECT file, start_line, end_line, start_column, end_column
                  FROM "references" as refs
                  WHERE refs.identifier = ?
                    AND refs.type = ?
                    AND refs.module = ?
                    AND refs.source = 'user'
                  """,
                  [attribute, "attribute", module]
                )

              :unknown ->
                file
                |> Variables.list_variable_references({line, col})
                |> Enum.map(fn {_name, {startl..endl//_, startc..endc//_}} ->
                  [file, startl, endl, startc, endc]
                end)
            end

          for [file, startl, endl, startc, endc] <- references,
              match?({:ok, _}, File.stat(file)) do
            %Location{
              uri: "file://#{file}",
              range: %Range{
                start: %Position{line: clamp(startl - 1), character: clamp(startc - 1)},
                end: %Position{line: clamp(endl - 1), character: clamp(endc - 1)}
              }
            }
          end
        end)
      end)

    {:reply, locations, lsp}
  end

  def handle_request(%TextDocumentHover{params: %{position: position, text_document: %{uri: uri}}}, lsp) do
    file = URI.parse(uri).path
    line = position.line + 1
    col = position.character + 1

    select = ~w<identifier type module arity start_line start_column end_line end_column>a

    reference_query = ~Q"""
    SELECT :select
    FROM "references" refs
    WHERE refs.file = ?
      AND ? BETWEEN refs.start_line AND refs.end_line
      AND ? BETWEEN refs.start_column AND refs.end_column
    ORDER BY refs.id ASC
    LIMIT 1
    """

    locations =
      dispatch(assigns(lsp).registry, :databases, fn databases ->
        Enum.flat_map(databases, fn {database, _} ->
          DB.query(database, reference_query, args: [file, line, col], select: select)
        end)
      end)

    resp =
      case locations do
        [reference] ->
          mod =
            if reference.module == String.downcase(reference.module) do
              String.to_atom(reference.module)
            else
              Module.concat([reference.module])
            end

          result =
            dispatch(assigns(lsp).registry, :runtimes, fn entries ->
              [result] =
                for {runtime, %{uri: wuri}} <- entries, String.starts_with?(uri, wuri) do
                  Runtime.call(runtime, {Code, :fetch_docs, [mod]})
                end

              result
            end)

          value =
            with {:ok, result} <- result,
                 %NextLS.Docs{} = doc <- NextLS.Docs.new(result, mod) do
              case reference.type do
                "alias" ->
                  NextLS.Docs.module(doc)

                "function" ->
                  NextLS.Docs.function(doc, fn name, a, documentation, _other ->
                    to_string(name) == reference.identifier and documentation != :hidden and
                      a >= reference.arity
                  end)

                _ ->
                  nil
              end
            else
              _ -> nil
            end

          with value when is_binary(value) <- value do
            %GenLSP.Structures.Hover{
              contents: %GenLSP.Structures.MarkupContent{
                kind: GenLSP.Enumerations.MarkupKind.markdown(),
                value: String.trim(value)
              },
              range: %Range{
                start: %Position{
                  line: reference.start_line - 1,
                  character: reference.start_column - 1
                },
                end: %Position{line: reference.end_line - 1, character: reference.end_column - 1}
              }
            }
          end

        _ ->
          nil
      end

    {:reply, resp, lsp}
  end

  def handle_request(%WorkspaceSymbol{params: %{query: query}}, lsp) do
    case_sensitive? = String.downcase(query) != query

    symbols = fn pid ->
      rows =
        DB.query(
          pid,
          ~Q"""
          SELECT *
          FROM symbols
          WHERE source = 'user';
          """,
          []
        )

      for [_pk, module, file, type, name, _params, line, column | _] <- rows do
        %{
          module: module,
          file: file,
          type: type,
          name: name,
          line: line,
          column: column
        }
      end
    end

    symbols =
      dispatch(assigns(lsp).registry, :databases, fn entries ->
        filtered_symbols =
          for {pid, _} <- entries,
              symbol <- symbols.(pid),
              score = fuzzy_match(symbol.name, query, case_sensitive?) do
            name =
              if symbol.type in ["defstruct", "attribute"] do
                "#{symbol.name}"
              else
                "#{symbol.type} #{symbol.name}"
              end

            {%SymbolInformation{
               name: name,
               kind: elixir_kind_to_lsp_kind(symbol.type),
               location: %Location{
                 uri: "file://#{symbol.file}",
                 range: %Range{
                   start: %Position{
                     line: symbol.line - 1,
                     character: symbol.column - 1
                   },
                   end: %Position{
                     line: symbol.line - 1,
                     character: symbol.column - 1
                   }
                 }
               }
             }, score}
          end

        filtered_symbols |> List.keysort(1, :desc) |> Enum.map(&elem(&1, 0))
      end)

    {:reply, symbols, lsp}
  end

  def handle_request(%TextDocumentFormatting{params: %{text_document: %{uri: uri}}}, lsp) do
    # NextLS.Logger.log(assigns(lsp).logger, "formatting start: #{System.system_time()}")
    document = assigns(lsp).documents[uri]

    if is_list(document) do
      result =
        dispatch_to_workspace(assigns(lsp).registry, uri, fn runtime, %{uri: wuri} ->
          # NextLS.Logger.log(assigns(lsp).logger, "dispatched to workspace: #{System.system_time()}")

          with {:ok, {formatter, _}} <-
                 Runtime.call(
                   runtime,
                   {:_next_ls_private_formatter, :formatter_for_file, [URI.parse(uri).path]}
                 ),
               # NextLS.Logger.log(assigns(lsp).logger, "got formatter: #{System.system_time()}"),
               {:ok, response} when is_binary(response) or is_list(response) <-
                 Runtime.call(
                   runtime,
                   {Kernel, :apply, [formatter, [Enum.join(document, "\n")]]}
                 ) do
            # NextLS.Logger.log(assigns(lsp).logger, "finished formatting: #{System.system_time()}")

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
              GenLSP.notify(lsp, %WindowShowMessage{
                params: %ShowMessageParams{
                  type: MessageType.info(),
                  message: "The NextLS runtime is still initializing!"
                }
              })

              {:reply, nil, lsp}

            e ->
              case e do
                {:ok, {:badrpc, {:EXIT, {%{description: description, file: file}, _stacktrace}}}} ->
                  file = Path.relative_to(file, URI.parse(wuri).path)

                  NextLS.Logger.show_message(
                    assigns(lsp).logger,
                    :error,
                    "Failed to format #{file}: #{description}"
                  )

                  NextLS.Logger.warning(
                    assigns(lsp).logger,
                    "Failed to format #{file}: #{description}"
                  )

                _ ->
                  abs_file = URI.parse(uri).path
                  root_dir = URI.parse(wuri).path
                  file = Path.relative_to(abs_file, root_dir)
                  NextLS.Logger.show_message(assigns(lsp).logger, :error, "Failed to format #{file}")
                  NextLS.Logger.warning(assigns(lsp).logger, "Failed to format #{file}")
              end

              {:reply, nil, lsp}
          end
        end)

      with %GenLSP.ErrorResponse{} <- result do
        {:reply, result, lsp}
      end
    else
      NextLS.Logger.warning(
        assigns(lsp).logger,
        "The file #{uri} was not found in the server's process state. Something must have gone wrong when opening, changing, or saving the file."
      )

      {:reply, nil, lsp}
    end
  end

  def handle_request(%GenLSP.Requests.CompletionItemResolve{params: completion_item}, lsp) do
    completion_item =
      case completion_item.data do
        nil ->
          completion_item

        %{"uri" => uri, "data" => data} ->
          data = data |> Base.decode64!() |> :erlang.binary_to_term()

          module =
            case data do
              {mod, _function, _arity} -> mod
              mod -> mod
            end

          result =
            dispatch_to_workspace(assigns(lsp).registry, uri, fn runtime, _entry ->
              Runtime.call(runtime, {Code, :fetch_docs, [module]})
            end)

          docs =
            with {:ok, doc} <- result,
                 %NextLS.Docs{} = doc <- NextLS.Docs.new(doc, module) do
              case data do
                {_mod, function, arity} ->
                  NextLS.Docs.function(doc, fn name, a, documentation, _other ->
                    to_string(name) == function and documentation != :hidden and a >= arity
                  end)

                mod when is_atom(mod) ->
                  NextLS.Docs.module(doc)
              end
            else
              _ -> nil
            end

          %{completion_item | documentation: docs}
      end

    {:reply, completion_item, lsp}
  end

  def handle_request(%TextDocumentCompletion{params: %{text_document: %{uri: uri}, position: position}}, lsp) do
    document = assigns(lsp).documents[uri]

    document_slice =
      document
      |> Enum.take(position.line + 1)
      |> Enum.reverse()
      |> then(fn [last_line | rest] ->
        {line, _forget} = String.split_at(last_line, position.character)
        [line | rest]
      end)
      |> Enum.reverse()
      |> Enum.join("\n")

    with_cursor =
      case Spitfire.container_cursor_to_quoted(document_slice) do
        {:ok, with_cursor} -> with_cursor
        {:error, with_cursor, _} -> with_cursor
      end

    results =
      with {root_path, entries} <-
             dispatch_to_workspace(assigns(lsp).registry, uri, fn runtime, %{uri: wuri} ->
               {:ok, {_, _, _, macro_env}} =
                 Runtime.expand(runtime, with_cursor, Path.basename(uri))

               doc =
                 document_slice
                 |> String.to_charlist()
                 |> Enum.reverse()

               result = NextLS.Autocomplete.expand(doc, runtime, macro_env)

               case result do
                 {:yes, entries} -> {wuri, entries}
                 _ -> {wuri, []}
               end
             end) do
        entries
        |> Enum.reduce([], fn %{name: name, kind: kind} = symbol, results ->
          {label, kind, docs} =
            case kind do
              :struct ->
                {name, CompletionItemKind.struct(), ""}

              :function ->
                {"#{name}/#{symbol.arity}", CompletionItemKind.function(), symbol[:docs] || ""}

              :module ->
                {name, CompletionItemKind.module(), symbol[:docs] || ""}

              :variable ->
                {to_string(name), CompletionItemKind.variable(), ""}

              :dir ->
                {name, CompletionItemKind.folder(), ""}

              :file ->
                {name, CompletionItemKind.file(), ""}

              :reserved ->
                {name, CompletionItemKind.keyword(), ""}

              :keyword ->
                {name, CompletionItemKind.field(), ""}

              :attribute ->
                {name, CompletionItemKind.property(), ""}

              :sigil ->
                {name, CompletionItemKind.function(), ""}

              _ ->
                {name, CompletionItemKind.text(), ""}
            end

          completion_item =
            %GenLSP.Structures.CompletionItem{
              label: label,
              kind: kind,
              insert_text: to_string(name),
              documentation: docs,
              data:
                if symbol[:data] do
                  %{uri: uri, data: symbol[:data] |> :erlang.term_to_binary() |> Base.encode64()}
                end
            }

          root_path = root_path |> URI.parse() |> Map.get(:path)

          case NextLS.Snippet.get(label, nil, uri: Path.relative_to(URI.parse(uri).path, root_path)) do
            nil -> [completion_item | results]
            %{} = snippet -> [Map.merge(completion_item, snippet) | results]
          end
        end)
        |> Enum.reverse()
      end

    {:reply, results, lsp}
  rescue
    e ->
      NextLS.Logger.warning(
        assigns(lsp).logger,
        "Failed to run completion request: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      {:reply, [], lsp}
  end

  def handle_request(
        %GenLSP.Requests.WorkspaceExecuteCommand{
          params: %GenLSP.Structures.ExecuteCommandParams{command: command} = params
        },
        lsp
      ) do
    reply =
      case command do
        "from-pipe" ->
          [arguments] = params.arguments

          uri = arguments["uri"]
          position = arguments["position"]
          text = assigns(lsp).documents[uri]

          Pipe.from(%{
            uri: uri,
            text: text,
            position: position
          })

        "to-pipe" ->
          [arguments] = params.arguments

          uri = arguments["uri"]
          position = arguments["position"]
          text = assigns(lsp).documents[uri]

          Pipe.to(%{
            uri: uri,
            text: text,
            position: position
          })

        "alias-refactor" ->
          [arguments] = params.arguments

          uri = arguments["uri"]
          position = arguments["position"]
          text = assigns(lsp).documents[uri]

          NextLS.Commands.Alias.run(%{
            uri: uri,
            text: text,
            position: position
          })

        _ ->
          NextLS.Logger.show_message(
            assigns(lsp).logger,
            :warning,
            "[Next LS] Unknown workspace command: #{command}"
          )

          nil
      end

    case reply do
      %WorkspaceEdit{} = edit ->
        GenLSP.request(lsp, %WorkspaceApplyEdit{
          id: System.unique_integer([:positive]),
          params: %ApplyWorkspaceEditParams{label: NextLS.Commands.label(command), edit: edit}
        })

      _reply ->
        :ok
    end

    {:reply, reply, lsp}
  rescue
    e ->
      NextLS.Logger.show_message(
        assigns(lsp).logger,
        :error,
        "[Next LS] #{command} has failed, see the logs for more details"
      )

      NextLS.Logger.error(assigns(lsp).logger, Exception.format(:error, e, __STACKTRACE__))

      {:reply, nil, lsp}
  end

  def handle_request(%Shutdown{}, lsp) do
    {:reply, nil, assign(lsp, exit_code: 0)}
  end

  def handle_request(%{method: method}, lsp) do
    NextLS.Logger.warning(assigns(lsp).logger, "Method Not Found: #{method}")

    {:reply,
     %ErrorResponse{
       code: ErrorCodes.method_not_found(),
       message: "Method Not Found: #{method}"
     }, lsp}
  end

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    NextLS.Logger.log(assigns(lsp).logger, "NextLS v#{version()} has initialized!")

    NextLS.Logger.log(
      assigns(lsp).logger,
      "Log file located at #{Path.join(File.cwd!(), ".elixir-tools/next-ls.log")}"
    )

    with opts when is_list(opts) <- assigns(lsp).auto_update do
      {:ok, _} =
        DynamicSupervisor.start_child(
          assigns(lsp).dynamic_supervisor,
          {NextLS.Updater, Keyword.put(opts, :logger, assigns(lsp).logger)}
        )
    end

    for {id, extension} <- assigns(lsp).extensions do
      child =
        DynamicSupervisor.start_child(
          assigns(lsp).dynamic_supervisor,
          {extension,
           settings: Map.fetch!(assigns(lsp).init_opts.extensions, id),
           logger: assigns(lsp).logger,
           cache: assigns(lsp).cache,
           registry: assigns(lsp).registry,
           publisher: lsp.pid,
           task_supervisor: assigns(lsp).runtime_task_supervisor}
        )

      case child do
        {:ok, _pid} -> :ok
        :ignore -> :ok
      end
    end

    with %{dynamic_registration: true} <-
           assigns(lsp).client_capabilities.workspace.did_change_watched_files do
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
    end

    BundledElixir.install(assigns(lsp).bundle_base, assigns(lsp).logger)
    NextLS.Logger.log(assigns(lsp).logger, "Booting runtimes...")

    parent = lsp.pid

    elixir_bin_path =
      cond do
        assigns(lsp).is_1_17 ->
          "elixir" |> System.find_executable() |> Path.dirname()

        assigns(lsp).init_opts.elixir_bin_path != nil ->
          assigns(lsp).init_opts.elixir_bin_path

        assigns(lsp).init_opts.experimental.completions.enable ->
          BundledElixir.binpath(assigns(lsp).bundle_base)

        true ->
          "elixir" |> System.find_executable() |> Path.dirname()
      end

    for %{uri: uri, name: name} <- assigns(lsp).workspace_folders do
      token = Progress.token()
      Progress.start(lsp, token, "Initializing NextLS runtime for folder #{name}...")
      working_dir = URI.parse(uri).path

      {:ok, _} =
        DynamicSupervisor.start_child(
          assigns(lsp).dynamic_supervisor,
          {NextLS.Runtime.Supervisor,
           path: Path.join(working_dir, ".elixir-tools"),
           name: name,
           lsp: lsp,
           lsp_pid: parent,
           registry: assigns(lsp).registry,
           logger: assigns(lsp).logger,
           runtime: [
             task_supervisor: assigns(lsp).runtime_task_supervisor,
             working_dir: working_dir,
             uri: uri,
             mix_env: assigns(lsp).init_opts.mix_env,
             mix_target: assigns(lsp).init_opts.mix_target,
             mix_home: assigns(lsp).mix_home,
             mix_archives: assigns(lsp).mix_archives,
             elixir_bin_path: elixir_bin_path,
             on_initialized: fn status ->
               if status == :ready do
                 Progress.stop(lsp, token, "NextLS runtime for folder #{name} has initialized!")
                 NextLS.Logger.log(assigns(lsp).logger, "Runtime for folder #{name} is ready...")

                 msg = {:runtime_ready, name, self()}

                 dispatch(assigns(lsp).registry, :extensions, fn entries ->
                   for {pid, _} <- entries, do: send(pid, msg)
                 end)

                 Process.send(parent, msg, [])
               else
                 Progress.stop(lsp, token)

                 send(parent, {:runtime_failed, name, status})

                 NextLS.Logger.error(
                   assigns(lsp).logger,
                   "Runtime for folder #{name} failed to initialize"
                 )
               end
             end,
             logger: assigns(lsp).logger
           ]}
        )
    end

    {:noreply, assign(lsp, elixir_bin_path: elixir_bin_path)}
  end

  # TODO: add some test cases for saving files in multiple workspaces
  def handle_notification(
        %TextDocumentDidSave{
          params: %GenLSP.Structures.DidSaveTextDocumentParams{text: text, text_document: %{uri: uri}}
        },
        lsp
      ) do
    # NextLS.Logger.log(assigns(lsp).logger, "did save pid: " <> inspect(self()))

    refresh_refs =
      if assigns(lsp).ready do
        # dispatching to all workspaces
        dispatch(assigns(lsp).registry, :runtimes, fn entries ->
          for {pid, %{name: name, uri: wuri}} <- entries, String.starts_with?(uri, wuri), into: %{} do
            token = Progress.token()
            Progress.start(lsp, token, "Compiling #{name}...")

            ref = make_ref()
            Runtime.compile(pid, caller_ref: ref)

            {ref, {token, "Compiled #{name}!"}}
          end
        end)
      else
        Map.new()
      end

    insert_document(lsp, uri, text)
    assign(lsp, fn assigns -> update_in(assigns.refresh_refs, fn r -> Map.merge(r, refresh_refs) end) end)

    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidChange{params: %{text_document: %{uri: uri}, content_changes: [%{text: text}]}},
        lsp
      ) do
    insert_document(lsp, uri, text)
    {:noreply, lsp}
  end

  def handle_notification(
        %TextDocumentDidOpen{
          params: %DidOpenTextDocumentParams{text_document: %TextDocumentItem{text: text, uri: uri}}
        },
        lsp
      ) do
    insert_document(lsp, uri, text)
    {:noreply, lsp}
  end

  def handle_notification(
        %WorkspaceDidChangeWorkspaceFolders{
          params: %DidChangeWorkspaceFoldersParams{event: %WorkspaceFoldersChangeEvent{added: added, removed: removed}}
        },
        lsp
      ) do
    NextLS.Registry.dispatch(assigns(lsp).registry, :runtime_supervisors, fn entries ->
      names = Enum.map(entries, fn {_, %{name: name}} -> name end)

      for %{name: name, uri: uri} <- added, name not in names do
        NextLS.Logger.log(assigns(lsp).logger, "Adding workspace folder #{name}")
        token = Progress.token()
        Progress.start(lsp, token, "Initializing NextLS runtime for folder #{name}...")
        parent = lsp.pid
        working_dir = URI.parse(uri).path

        {:ok, _} =
          NextLS.Runtime.boot(assigns(lsp).dynamic_supervisor,
            path: Path.join(working_dir, ".elixir-tools"),
            name: name,
            lsp: lsp,
            lsp_pid: parent,
            registry: assigns(lsp).registry,
            runtime: [
              task_supervisor: assigns(lsp).runtime_task_supervisor,
              working_dir: working_dir,
              elixir_bin_path: assigns(lsp).elixir_bin_path,
              uri: uri,
              mix_env: assigns(lsp).init_opts.mix_env,
              mix_target: assigns(lsp).init_opts.mix_target,
              mix_home: assigns(lsp).mix_home,
              mix_archives: assigns(lsp).mix_archives,
              on_initialized: fn status ->
                if status == :ready do
                  Progress.stop(lsp, token, "NextLS runtime for folder #{name} has initialized!")
                  NextLS.Logger.log(assigns(lsp).logger, "Runtime for folder #{name} is ready...")

                  msg = {:runtime_ready, name, self()}

                  dispatch(assigns(lsp).registry, :extensions, fn entries ->
                    for {pid, _} <- entries, do: send(pid, msg)
                  end)

                  send(parent, msg)
                else
                  Progress.stop(lsp, token)

                  send(parent, {:runtime_failed, name, status})

                  NextLS.Logger.error(
                    assigns(lsp).logger,
                    "Runtime for folder #{name} failed to initialize"
                  )
                end
              end,
              logger: assigns(lsp).logger
            ]
          )
      end

      names = Enum.map(removed, & &1.name)

      for {pid, %{name: name}} <- entries, name in names do
        NextLS.Logger.log(assigns(lsp).logger, "Removing workspace folder #{name}")
        NextLS.Runtime.stop(assigns(lsp).dynamic_supervisor, pid)
      end
    end)

    {:noreply, lsp}
  end

  def handle_notification(%WorkspaceDidChangeWatchedFiles{params: %DidChangeWatchedFilesParams{changes: changes}}, lsp) do
    lsp =
      for %{type: type, uri: uri} <- changes, reduce: lsp do
        lsp ->
          file = URI.parse(uri).path

          cond do
            type == FileChangeType.created() ->
              case File.read(file) do
                {:ok, text} -> insert_document(lsp, uri, text)
                _ -> lsp
              end

            type == FileChangeType.changed() ->
              case File.read(file) do
                {:ok, text} -> insert_document(lsp, uri, text)
                _ -> lsp
              end

            type == FileChangeType.deleted() ->
              if File.exists?(file) do
                lsp
              else
                dispatch(assigns(lsp).registry, :databases, fn entries ->
                  for {pid, _} <- entries do
                    NextLS.DB.query(
                      pid,
                      ~Q"""
                      DELETE FROM symbols
                      WHERE symbols.file = ?;
                      """,
                      [file]
                    )

                    NextLS.DB.query(
                      pid,
                      ~Q"""
                      DELETE FROM 'references' AS refs
                      WHERE refs.file = ?;
                      """,
                      [file]
                    )
                  end
                end)

                assign(lsp, fn assigns -> update_in(assigns.documents, &Map.delete(&1, uri)) end)
              end
          end
      end

    {:noreply, lsp}
  end

  def handle_notification(%Exit{}, lsp) do
    System.halt(assigns(lsp).exit_code)

    {:noreply, lsp}
  end

  def handle_notification(_notification, lsp) do
    # dbg("unhandled notification")
    # dbg(notification)

    {:noreply, lsp}
  end

  def handle_info({:compiler_result, caller_ref, name, result} = _msg, lsp) do
    {{token, msg}, refs} = Map.pop(assigns(lsp).refresh_refs, caller_ref)

    case result do
      {_, diagnostics} when is_list(diagnostics) ->
        Registry.dispatch(assigns(lsp).registry, :extensions, fn entries ->
          for {pid, _} <- entries, do: send(pid, {:compiler, diagnostics})
        end)

        NextLS.Logger.info(assigns(lsp).logger, "Compiled #{name}!")

      {:error, %Mix.Error{message: "Can't continue due to errors on dependencies"}} ->
        send(lsp.pid, {:runtime_failed, name, {:error, :deps}})

      unknown ->
        NextLS.Logger.warning(
          assigns(lsp).logger,
          "Unexpected compiler response: #{inspect(unknown)}"
        )
    end

    Progress.stop(lsp, token, msg)

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info({:compiler_canceled, caller_ref}, lsp) do
    {{token, msg}, refs} = Map.pop(assigns(lsp).refresh_refs, caller_ref)

    Progress.stop(lsp, token, msg)

    {:noreply, assign(lsp, refresh_refs: refs)}
  end

  def handle_info(:publish, lsp) do
    Task.start(fn ->
      all =
        for {_namespace, cache} <- DiagnosticCache.get(assigns(lsp).cache),
            {file, diagnostics} <- cache,
            reduce: %{} do
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
    end)

    {:noreply, lsp}
  end

  def handle_info({:runtime_ready, name, runtime_pid}, lsp) do
    case NextLS.Registry.dispatch(assigns(lsp).registry, :databases, fn entries ->
           Enum.find(entries, fn {_, %{runtime: runtime}} -> runtime == name end)
         end) do
      {_, %{mode: mode}} ->
        token = Progress.token()
        Progress.start(lsp, token, "Compiling #{name}...")

        ref = make_ref()
        Runtime.compile(runtime_pid, caller_ref: ref, force: mode == :reindex)

        refresh_refs = Map.put(assigns(lsp).refresh_refs, ref, {token, "Compiled #{name}!"})

        {:noreply, assign(lsp, ready: true, refresh_refs: refresh_refs)}

      nil ->
        {:noreply, assign(lsp, ready: true)}
    end
  end

  def handle_info({:runtime_failed, name, status}, lsp) do
    {pid, %{init_arg: init_arg}} =
      NextLS.Registry.dispatch(assigns(lsp).registry, :runtime_supervisors, fn entries ->
        Enum.find(entries, fn {_pid, %{name: n}} -> n == name end)
      end)

    :ok = DynamicSupervisor.terminate_child(assigns(lsp).dynamic_supervisor, pid)

    if status == {:error, :deps} && assigns(lsp).client_capabilities.window.show_message do
      resp =
        GenLSP.request(
          lsp,
          %GenLSP.Requests.WindowShowMessageRequest{
            id: System.unique_integer([:positive]),
            params: %GenLSP.Structures.ShowMessageRequestParams{
              type: MessageType.error(),
              message: "The NextLS runtime failed with errors on dependencies. Would you like to re-fetch them?",
              actions: [
                %MessageActionItem{title: "yes"},
                %MessageActionItem{title: "no"}
              ]
            }
          },
          :infinity
        )

      case resp do
        %MessageActionItem{title: "yes"} ->
          NextLS.Logger.info(
            assigns(lsp).logger,
            "Running `mix deps.get` in directory #{init_arg[:runtime][:working_dir]}"
          )

          File.rm_rf!(Path.join(init_arg[:runtime][:working_dir], ".elixir-tools/_build"))
          File.rm_rf!(Path.join(init_arg[:runtime][:working_dir], ".elixir-tools/_build2"))

          case System.cmd("mix", ["deps.get"],
                 env: [{"MIX_ENV", "dev"}, {"MIX_BUILD_ROOT", ".elixir-tools/_build"}],
                 cd: init_arg[:runtime][:working_dir],
                 stderr_to_stdout: true
               ) do
            {msg, 0} ->
              NextLS.Logger.info(
                assigns(lsp).logger,
                "Restarting runtime #{name} for directory #{init_arg[:runtime][:working_dir]}"
              )

              NextLS.Logger.info(assigns(lsp).logger, msg)

              {:ok, _} =
                DynamicSupervisor.start_child(
                  assigns(lsp).dynamic_supervisor,
                  {NextLS.Runtime.Supervisor, init_arg}
                )

            {msg, _} ->
              NextLS.Logger.warning(
                assigns(lsp).logger,
                "Failed to run `mix deps.get` in directory #{init_arg[:runtime][:working_dir]} with message: #{msg}"
              )
          end

        _ ->
          NextLS.Logger.info(assigns(lsp).logger, "Not running `mix deps.get`")
      end
    else
      unless assigns(lsp).client_capabilities.window.show_message do
        NextLS.Logger.info(
          assigns(lsp).logger,
          "Client does not support window/showMessageRequest"
        )
      end
    end

    {:noreply, lsp}
  end

  def handle_info({ref, {:runtime_failed, _, _} = error}, lsp) do
    %{refresh_refs: refs} = assigns(lsp)

    if is_map_key(refs, ref) do
      Process.demonitor(ref, [:flush])
      {{token, msg}, refs} = Map.pop(refs, ref)

      Progress.stop(lsp, token, msg)
      send(lsp.pid, error)

      {:noreply, assign(lsp, refresh_refs: refs)}
    else
      {:noreply, lsp}
    end
  end

  def handle_info(message, lsp) do
    NextLS.Logger.log(assigns(lsp).logger, "Unhandled message: #{inspect(message)}")
    NextLS.Logger.log(assigns(lsp).logger, "process assigns=#{inspect(assigns(lsp))}")
    {:noreply, lsp}
  end

  def version do
    case :application.get_key(:next_ls, :vsn) do
      {:ok, version} -> to_string(version)
      _ -> "dev"
    end
  end

  defp elixir_kind_to_lsp_kind("defmodule"), do: SymbolKind.module()
  defp elixir_kind_to_lsp_kind("defstruct"), do: SymbolKind.struct()
  defp elixir_kind_to_lsp_kind("attribute"), do: SymbolKind.property()

  defp elixir_kind_to_lsp_kind(kind) when kind in ["def", "defp", "defmacro", "defmacrop"], do: SymbolKind.function()

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
    after
      1000 ->
        %GenLSP.ErrorResponse{code: GenLSP.Enumerations.ErrorCodes.internal_error(), message: "Timeout"}
    end
  end

  defp dispatch_to_workspace(registry, uri, callback) do
    ref = make_ref()

    me = self()

    Registry.dispatch(registry, :runtimes, fn entries ->
      [result] =
        for {runtime, %{uri: wuri} = entry} <- entries, String.starts_with?(uri, wuri) do
          callback.(runtime, entry)
        end

      send(me, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    after
      1000 ->
        %GenLSP.ErrorResponse{code: GenLSP.Enumerations.ErrorCodes.internal_error(), message: "Timeout"}
    end
  end

  defp symbol_info(file, line, col, database) do
    definition_query = ~Q"""
    SELECT module, type, name
    FROM "symbols" sym
    WHERE sym.file = ?
      AND sym.line = ?
      AND ? BETWEEN sym.column AND sym.end_column
    ORDER BY sym.id ASC
    LIMIT 1
    """

    reference_query = ~Q"""
    SELECT identifier, type, module
    FROM "references" refs
    WHERE refs.file = ?
      AND ? BETWEEN refs.start_line AND refs.end_line
      AND ? BETWEEN refs.start_column AND refs.end_column
    ORDER BY refs.id ASC
    LIMIT 1
    """

    case DB.query(database, definition_query, [file, line, col]) do
      [[module, "defmodule", _]] ->
        {:module, module}

      [[module, "defstruct", _]] ->
        {:module, module}

      [[module, "def", function]] ->
        {:function, module, function}

      [[module, "defp", function]] ->
        {:function, module, function}

      [[module, "defmacro", function]] ->
        {:function, module, function}

      [[module, "attribute", attribute]] ->
        {:attribute, module, attribute}

      _unknown_definition ->
        case DB.query(database, reference_query, [file, line, col]) do
          [[function, "function", module]] ->
            {:function, module, function}

          [[attribute, "attribute", module]] ->
            {:attribute, module, attribute}

          [[_alias, "alias", module]] ->
            {:module, module}

          _unknown_reference ->
            :unknown
        end
    end
  end

  defp clamp(line), do: max(line, 0)

  # This is an implementation of a sequential fuzzy string matching algorithm,
  # similar to those used in code editors like Sublime Text.
  # It is based on Forrest Smith's work on https://github.com/forrestthewoods/lib_fts/)
  # and his blog post https://www.forrestthewoods.com/blog/reverse_engineering_sublime_texts_fuzzy_match/.
  #
  # Function checks if letters from the query present in the source in correct order.
  # It calculates match score only for matching sources.

  defp fuzzy_match(_source, "", _case_sensitive), do: 1

  defp fuzzy_match(source, query, case_sensitive) do
    source_converted = if case_sensitive, do: source, else: String.downcase(source)
    source_letters = String.codepoints(source_converted)
    query_letters = String.codepoints(query)

    if do_fuzzy_match?(source_letters, query_letters) do
      source_anycase = String.codepoints(source)
      source_downcase = query |> String.downcase() |> String.codepoints()

      calc_match_score(source_anycase, source_downcase, %{leading: true, separator: true}, 0)
    else
      false
    end
  end

  defp do_fuzzy_match?(_source_letters, []), do: true

  defp do_fuzzy_match?(source_letters, [query_head | query_rest]) do
    case match_letter(source_letters, query_head) do
      :no_match -> false
      rest_source_letters -> do_fuzzy_match?(rest_source_letters, query_rest)
    end
  end

  defp match_letter([], _query_letter), do: :no_match

  defp match_letter([source_letter | source_rest], query_letter) when query_letter == source_letter, do: source_rest

  defp match_letter([_ | source_rest], query_letter), do: match_letter(source_rest, query_letter)

  defp calc_match_score(_source_letters, [], _traits, score), do: score

  defp calc_match_score(source_letters, [query_letter | query_rest], traits, score) do
    {rest_source_letters, new_traits, new_score} =
      calc_letter_score(source_letters, query_letter, traits, score)

    calc_match_score(rest_source_letters, query_rest, new_traits, new_score)
  end

  defp calc_letter_score([source_letter | source_rest], query_letter, traits, score) do
    separator? = source_letter in ["_", ".", "-", "/", " "]
    source_letter_downcase = String.downcase(source_letter)
    upper? = source_letter_downcase != source_letter

    if query_letter == source_letter_downcase do
      new_traits = %{matched: true, leading: false, separator: separator?, upper: upper?}
      new_score = calc_matched_bonus(score, traits, new_traits)

      {source_rest, new_traits, new_score}
    else
      new_traits = %{
        matched: false,
        separator: separator?,
        upper: upper?,
        leading: traits.leading
      }

      new_score = calc_unmatched_penalty(score, traits)

      calc_letter_score(source_rest, query_letter, new_traits, new_score)
    end
  end

  # bonus if match occurs after a separator or on the first letter
  defp calc_matched_bonus(score, %{separator: true}, _new_traits), do: score + 30

  # bonus if match is uppercase and previous is lowercase
  defp calc_matched_bonus(score, %{upper: false}, %{upper: true}), do: score + 30

  # bonus for adjacent matches
  defp calc_matched_bonus(score, %{matched: true}, _new_traits), do: score + 15

  defp calc_matched_bonus(score, _traits, _new_traits), do: score

  # penalty applied for every letter in str before the first match
  defp calc_unmatched_penalty(score, %{leading: true}) when score > -15, do: score - 5

  # penalty for unmatched letter
  defp calc_unmatched_penalty(score, _traits), do: score - 1

  defp insert_document(lsp, uri, text) do
    assign(lsp, fn assigns -> put_in(assigns.documents[uri], String.split(text, "\n")) end)
  end

  defmodule InitOpts.Experimental do
    @moduledoc false
    defstruct completions: %{enable: false}
  end

  defmodule InitOpts.Extensions.Credo do
    @moduledoc false
    defstruct enable: true,
              cli_options: []
  end

  defmodule InitOpts.Extensions do
    @moduledoc false
    defstruct elixir: %{enable: true},
              credo: %NextLS.InitOpts.Extensions.Credo{}
  end

  defmodule InitOpts do
    @moduledoc false
    import Schematic

    alias NextLS.InitOpts.Experimental
    alias NextLS.InitOpts.Extensions

    defstruct mix_target: "host",
              mix_env: "dev",
              elixir_bin_path: nil,
              experimental: %Experimental{},
              extensions: %Extensions{}

    def validate(opts) do
      schematic =
        nullable(
          schema(__MODULE__, %{
            optional(:mix_target) => str(),
            optional(:mix_env) => str(),
            optional(:mix_env) => str(),
            optional(:elixir_bin_path) => str(),
            optional(:experimental) =>
              schema(Experimental, %{
                optional(:completions) =>
                  map(%{
                    {"enable", :enable} => bool()
                  })
              }),
            optional(:extensions) =>
              schema(Extensions, %{
                optional(:credo) =>
                  schema(NextLS.InitOpts.Extensions.Credo, %{
                    optional(:enable) => bool(),
                    optional(:cli_options) => list(str())
                  }),
                optional(:elixir) =>
                  map(%{
                    {"enable", :enable} => bool()
                  })
              })
          })
        )

      with {:ok, nil} <- unify(schematic, opts) do
        {:ok, %__MODULE__{}}
      end
    end
  end
end
