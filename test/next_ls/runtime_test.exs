defmodule NextLs.RuntimeTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  require Logger
  import ExUnit.CaptureLog

  alias NextLS.Runtime

  setup %{tmp_dir: tmp_dir} do
    File.cp_r!("test/support/project", tmp_dir)

    {:ok, logger} =
      Task.start_link(fn ->
        recv = fn recv ->
          receive do
            {:log, msg} ->
              Logger.debug(msg)
          end

          recv.(recv)
        end

        recv.(recv)
      end)

    [logger: logger, cwd: Path.absname(tmp_dir)]
  end

  test "can run code on the node", %{logger: logger, cwd: cwd} do
    capture_log(fn ->
      pid = start_supervised!({Runtime, working_dir: cwd, parent: logger})

      Process.link(pid)

      assert wait_for_ready(pid)
    end) =~ "Connected to node"
  end

  defp wait_for_ready(pid) do
    with false <- Runtime.ready?(pid) do
      Process.sleep(100)
      wait_for_ready(pid)
    end
  end
end
