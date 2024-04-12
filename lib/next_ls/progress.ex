defmodule NextLS.Progress do
  @moduledoc false
  @env Mix.env()
  def start(lsp, token, msg) do
    Task.start(fn ->
      # FIXME: gen_lsp should allow stubbing requests so we don't have to
      # set this in every test. For now, don't send it in the test env
      if @env != :test do
        GenLSP.request(lsp, %GenLSP.Requests.WindowWorkDoneProgressCreate{
          id: System.unique_integer([:positive]),
          params: %GenLSP.Structures.WorkDoneProgressCreateParams{
            token: token
          }
        })
      end

      GenLSP.notify(lsp, %GenLSP.Notifications.DollarProgress{
        params: %GenLSP.Structures.ProgressParams{
          token: token,
          value: %GenLSP.Structures.WorkDoneProgressBegin{kind: "begin", title: msg}
        }
      })
    end)
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

  def token do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end
end
