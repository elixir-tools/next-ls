defmodule NextLS.Progress do
  @moduledoc false

  alias GenLSP.Notifications.DollarProgress
  alias GenLSP.Structures.ProgressParams

  def start(lsp, token, msg) do
    Task.start(fn ->
      if lsp.assigns.client_capabilities.window.work_done_progress do
        GenLSP.request(lsp, %GenLSP.Requests.WindowWorkDoneProgressCreate{
          id: System.unique_integer([:positive]),
          params: %GenLSP.Structures.WorkDoneProgressCreateParams{
            token: token
          }
        })
      end

      GenLSP.notify(lsp, %DollarProgress{
        params: %ProgressParams{
          token: token,
          value: %GenLSP.Structures.WorkDoneProgressBegin{kind: "begin", title: msg}
        }
      })
    end)
  end

  def stop(lsp, token, msg \\ nil) do
    GenLSP.notify(lsp, %DollarProgress{
      params: %ProgressParams{
        token: token,
        value: %GenLSP.Structures.WorkDoneProgressEnd{
          kind: "end",
          message: msg
        }
      }
    })
  end

  def token do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end
end
