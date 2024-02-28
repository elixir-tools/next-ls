defmodule NextLS.UpdaterTest do
  use ExUnit.Case, async: true

  alias NextLS.Updater

  @moduletag :tmp_dir

  setup do
    me = self()

    {:ok, logger} =
      Task.start_link(fn ->
        recv = fn recv ->
          receive do
            {:"$gen_cast", msg} ->
              # dbg(msg)
              send(me, msg)
          end

          recv.(recv)
        end

        recv.(recv)
      end)

    [logger: logger]
  end

  test "downloads the exe", %{tmp_dir: tmp_dir, logger: logger} do
    api = Bypass.open(port: 8000)
    github = Bypass.open(port: 8001)

    Bypass.expect(api, "GET", "/repos/elixir-tools/next-ls/releases/latest", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{tag_name: "v1.0.0"}))
    end)

    exe = String.duplicate("time to hack\n", 1000)

    Bypass.expect(github, fn conn ->
      assert "GET" == conn.method
      assert "/elixir-tools/next-ls/releases/download/v1.0.0/next_ls_" <> rest = conn.request_path

      assert rest in [
               "darwin_arm64",
               "darwin_amd64",
               "linux_arm64",
               "linux_amd64",
               "windows_amd64"
             ]

      Plug.Conn.resp(conn, 200, exe)
    end)

    binpath = Path.join(tmp_dir, "nextls")
    File.write(binpath, "yoyoyo")

    Updater.run(
      current_version: Version.parse!("0.9.0"),
      binpath: binpath,
      api_host: "http://localhost:8000",
      github_host: "http://localhost:8001",
      logger: logger
    )

    assert File.read!(binpath) == exe
    assert File.stat!(binpath).mode == 33_261
    assert File.stat!(binpath).size > 10_000
    assert File.exists?(binpath <> "-0.9.0")
  end

  test "doesn't download when the version is at the latest", %{tmp_dir: tmp_dir, logger: logger} do
    api = Bypass.open(port: 8000)

    Bypass.expect(api, "GET", "/repos/elixir-tools/next-ls/releases/latest", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{tag_name: "v1.0.0"}))
    end)

    binpath = Path.join(tmp_dir, "nextls")

    Updater.run(
      current_version: Version.parse!("1.0.0"),
      binpath: binpath,
      api_host: "http://localhost:8000",
      github_host: "http://localhost:8001",
      logger: logger
    )

    refute File.exists?(binpath)
  end

  test "logs that it failed when api call fails", %{tmp_dir: tmp_dir, logger: logger} do
    binpath = Path.join(tmp_dir, "nextls")
    File.write(binpath, "yoyoyo")

    Updater.run(
      current_version: Version.parse!("1.0.0"),
      binpath: binpath,
      api_host: "http://localhost:8000",
      github_host: "http://localhost:8001",
      logger: logger,
      retry: false
    )

    assert_receive {:log, :error, "Failed to retrieve the latest version number of Next LS from the GitHub API: " <> _}
  end

  test "logs that it failed when download fails", %{tmp_dir: tmp_dir, logger: logger} do
    api = Bypass.open(port: 8000)

    Bypass.expect(api, "GET", "/repos/elixir-tools/next-ls/releases/latest", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{tag_name: "v1.0.0"}))
    end)

    binpath = Path.join(tmp_dir, "nextls")
    File.write(binpath, "yoyoyo")

    Updater.run(
      current_version: Version.parse!("0.9.0"),
      binpath: binpath,
      api_host: "http://localhost:8000",
      github_host: "http://localhost:8001",
      logger: logger,
      retry: false
    )

    assert_receive {:show_message, :error, "Failed to download version 1.0.0 of Next LS!"}
    assert_receive {:log, :error, "Failed to download Next LS: " <> _}
  end
end
