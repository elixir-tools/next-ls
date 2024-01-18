defmodule NextLS.ElixirExtension.CodeAction do
  @moduledoc false
  alias NextLS.CodeActionable
  alias NextLS.CodeActionable.Data

  @behaviour CodeActionable

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit

  def from(%Data{} = data) do
    do_code_action(data.diagnostic, data.document, data.uri)
  end

  defp do_code_action(%Diagnostic{data: %{"type" => "unused"}} = d, file, uri) do
    NextLS.ElixirExtension.CodeAction.UnusedVar.new(d, file, uri)
  end

  defp do_code_action(_, _, _), do: []

  defmodule UnusedVar do
    @moduledoc false
    @underscore "_"
    def new(diagnostic, _text, uri) do
      %Diagnostic{range: %{start: start}} = diagnostic

      [
        %CodeAction{
          title: "Underscore unused var",
          diagnostics: [diagnostic],
          edit: %WorkspaceEdit{
            changes: %{
              uri => [
                %TextEdit{
                  new_text: @underscore,
                  range: %Range{
                    start: start,
                    end: start
                  }
                }
              ]
            }
          }
        }
      ]
    end
  end
end
