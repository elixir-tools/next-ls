defmodule NextLS.ElixirExtension do
  @moduledoc false
  use GenServer

  alias NextLS.DiagnosticCache

  def start_link(args) do
    GenServer.start_link(
      __MODULE__,
      Keyword.take(args, [:cache, :registry, :publisher]),
      Keyword.take(args, [:name])
    )
  end

  @impl GenServer
  def init(args) do
    cache = Keyword.fetch!(args, :cache)
    registry = Keyword.fetch!(args, :registry)
    publisher = Keyword.fetch!(args, :publisher)

    Registry.register(registry, :extensions, :elixir)

    {:ok, %{cache: cache, registry: registry, publisher: publisher}}
  end

  @impl GenServer
  def handle_info({:runtime_ready, _path, _pid}, state) do
    {:noreply, state}
  end

  def handle_info({:compiler, diagnostics}, state) when is_list(diagnostics) do
    DiagnosticCache.clear(state.cache, :elixir)

    for d <- diagnostics do
      # TODO: some compiler diagnostics only have the line number
      #       but we want to only highlight the source code, so we
      #       need to read the text of the file (either from the lsp cache
      #       if the source code is "open", or read from disk) and calculate the
      #       column of the first non-whitespace character.
      #
      #       it is not clear to me whether the LSP process or the extension should
      #       be responsible for this. The open documents live in the LSP process
      DiagnosticCache.put(state.cache, :elixir, d.file, %GenLSP.Structures.Diagnostic{
        severity: severity(d.severity),
        message: IO.iodata_to_binary(d.message),
        source: d.compiler_name,
        range: range(d.position, Map.get(d, :span)),
        data: metadata(d)
      })
    end

    send(state.publisher, :publish)

    {:noreply, state}
  end

  defp severity(:error), do: GenLSP.Enumerations.DiagnosticSeverity.error()
  defp severity(:warning), do: GenLSP.Enumerations.DiagnosticSeverity.warning()
  defp severity(:info), do: GenLSP.Enumerations.DiagnosticSeverity.information()
  defp severity(:hint), do: GenLSP.Enumerations.DiagnosticSeverity.hint()

  defp range({start_line, start_col, end_line, end_col}, _) do
    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{
        line: clamp(start_line - 1),
        character: start_col - 1
      },
      end: %GenLSP.Structures.Position{
        line: clamp(end_line - 1),
        character: end_col - 1
      }
    }
  end

  defp range({startl, startc}, {endl, endc}) do
    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{
        line: clamp(startl - 1),
        character: startc - 1
      },
      end: %GenLSP.Structures.Position{
        line: clamp(endl - 1),
        character: endc - 1
      }
    }
  end

  defp range({line, col}, nil) do
    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{
        line: clamp(line - 1),
        character: col - 1
      },
      end: %GenLSP.Structures.Position{
        line: clamp(line - 1),
        character: 999
      }
    }
  end

  defp range(line, _) do
    %GenLSP.Structures.Range{
      start: %GenLSP.Structures.Position{
        line: clamp(line - 1),
        character: 0
      },
      end: %GenLSP.Structures.Position{
        line: clamp(line - 1),
        character: 999
      }
    }
  end

  def clamp(line), do: max(line, 0)

  @unused_variable ~r/variable\s\"[^\"]+\"\sis\sunused/
  defp metadata(diagnostic) do
    base = %{"namespace" => "elixir"}

    cond do
      is_binary(diagnostic.message) and diagnostic.message =~ @unused_variable ->
        Map.put(base, "type", "unused_variable")

      true ->
        base
    end
  end
end
