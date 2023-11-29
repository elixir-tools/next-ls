defmodule NextLS.UI.Router do
  use Plug.Router, copy_opts_to_assign: :opts
  use Plug.Debugger
  use NextLS.UI.Component

  require Logger

  @not_found ~s'''
  <!DOCTYPE html><html lang="en"><head></head><body>Not Found</body></html>
  '''

  def init(opts), do: opts

  if Mix.env() == :dev do
    plug :recompile

    defp recompile(conn, _) do
      WebDevUtils.CodeReloader.reload()

      conn
    end
  end

  plug Plug.Static, at: "/", from: "priv", cache_control_for_etags: "no-cache"
  plug :fetch_query_params

  plug :match
  plug :dispatch

  get "/" do
    response = NextLS.UI.HomePage.run(conn, %{query: conn.query_params})

    conn
    |> put_resp_header("Content-Type", "text/html")
    |> resp(200, response)
  end

  get "/node" do
    response = NextLS.UI.HomePage.node_information(%{node: conn.query_params["node"]})

    conn
    |> put_resp_header("Content-Type", "text/html")
    |> resp(200, response)
  end

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(NextLS.UI.Websocket.Reload, [], timeout: 60_000)
    |> halt()
  end

  get "/ws/logs" do
    conn
    |> WebSockAdapter.upgrade(NextLS.UI.Websocket.Logs, [], timeout: 60_000)
    |> halt()
  end

  get "/ws/activity" do
    conn
    |> WebSockAdapter.upgrade(NextLS.UI.Websocket.Activity, [registry: conn.assigns.opts[:registry]], timeout: 60_000)
    |> halt()
  end

  match _ do
    Logger.error("File not found: #{conn.request_path}")

    send_resp(conn, 404, @not_found)
  end
end
