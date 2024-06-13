defmodule NextLS.Aliases do
  @moduledoc false
  # necessary evil, just way too many aliases
  defmacro __using__(_) do
    quote do
      alias GenLSP.Enumerations.CodeActionKind
      alias GenLSP.Enumerations.CompletionItemKind
      alias GenLSP.Enumerations.ErrorCodes
      alias GenLSP.Enumerations.FileChangeType
      alias GenLSP.Enumerations.MessageType
      alias GenLSP.Enumerations.SymbolKind
      alias GenLSP.Enumerations.TextDocumentSyncKind
      alias GenLSP.ErrorResponse
      alias GenLSP.Notifications.Exit
      alias GenLSP.Notifications.Initialized
      alias GenLSP.Notifications.TextDocumentDidChange
      alias GenLSP.Notifications.TextDocumentDidOpen
      alias GenLSP.Notifications.TextDocumentDidSave
      alias GenLSP.Notifications.WindowShowMessage
      alias GenLSP.Notifications.WorkspaceDidChangeWatchedFiles
      alias GenLSP.Notifications.WorkspaceDidChangeWorkspaceFolders
      alias GenLSP.Requests.Initialize
      alias GenLSP.Requests.Shutdown
      alias GenLSP.Requests.TextDocumentCodeAction
      alias GenLSP.Requests.TextDocumentCompletion
      alias GenLSP.Requests.TextDocumentDefinition
      alias GenLSP.Requests.TextDocumentDocumentSymbol
      alias GenLSP.Requests.TextDocumentFormatting
      alias GenLSP.Requests.TextDocumentHover
      alias GenLSP.Requests.TextDocumentReferences
      alias GenLSP.Requests.WorkspaceApplyEdit
      alias GenLSP.Requests.WorkspaceSymbol
      alias GenLSP.Structures.ApplyWorkspaceEditParams
      alias GenLSP.Structures.CodeActionContext
      alias GenLSP.Structures.CodeActionOptions
      alias GenLSP.Structures.CodeActionParams
      alias GenLSP.Structures.Diagnostic
      alias GenLSP.Structures.DidChangeWatchedFilesParams
      alias GenLSP.Structures.DidChangeWorkspaceFoldersParams
      alias GenLSP.Structures.DidOpenTextDocumentParams
      alias GenLSP.Structures.InitializeParams
      alias GenLSP.Structures.InitializeResult
      alias GenLSP.Structures.Location
      alias GenLSP.Structures.MessageActionItem
      alias GenLSP.Structures.Position
      alias GenLSP.Structures.Range
      alias GenLSP.Structures.SaveOptions
      alias GenLSP.Structures.ServerCapabilities
      alias GenLSP.Structures.ShowMessageParams
      alias GenLSP.Structures.SymbolInformation
      alias GenLSP.Structures.TextDocumentIdentifier
      alias GenLSP.Structures.TextDocumentItem
      alias GenLSP.Structures.TextDocumentSyncOptions
      alias GenLSP.Structures.TextEdit
      alias GenLSP.Structures.WorkspaceEdit
      alias GenLSP.Structures.WorkspaceFoldersChangeEvent
    end
  end
end
