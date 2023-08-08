defmodule NextLS.Progress do
  @moduledoc false
  def start(lsp, token, msg) do
    GenLSP.notify(lsp, %GenLSP.Notifications.DollarProgress{
      params: %GenLSP.Structures.ProgressParams{
        token: token,
        value: %GenLSP.Structures.WorkDoneProgressBegin{
          kind: "begin",
          title: msg
        }
      }
    })
  end

  def stop(lsp, token, msg \\ nil) do
    GenLSP.notify(lsp, %GenLSP.Notifications.DollarProgress{
      params: %GenLSP.Structures.ProgressParams{
        token: token,
        value: %GenLSP.Structures.WorkDoneProgressEnd{
          kind: "end",
          message: msg
        }
      }
    })
  end
end
