defmodule NextLS.ElixirExtension.CodeAction.UnusedVariable do
  @moduledoc false

  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Range
  alias GenLSP.Structures.TextEdit
  alias GenLSP.Structures.WorkspaceEdit

  def new(diagnostic, _text, uri) do
    %Diagnostic{range: %{start: start}} = diagnostic

    [
      %CodeAction{
        title: "Underscore unused variable",
        diagnostics: [diagnostic],
        edit: %WorkspaceEdit{
          changes: %{
            uri => [
              %TextEdit{
                new_text: "_",
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
