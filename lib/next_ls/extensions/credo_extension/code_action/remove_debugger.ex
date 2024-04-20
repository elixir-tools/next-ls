defmodule NextLS.CredoExtension.CodeAction.RemoveDebugger do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit

  def new(diagnostic, _text, uri) do
    %Diagnostic{range: %Range{start: start}} = diagnostic

    [
      %CodeAction{
        title: "Remove debugger",
        diagnostics: [diagnostic],
        edit: %WorkspaceEdit{
          changes: %{
            uri => [
              %TextEdit{
                new_text: "",
                range: %Range{
                  start: %{start | character: 0},
                  end: %{start | character: 0, line: start.line + 1}
                }
              }
            ]
          }
        }
      }
    ]
  end
end
