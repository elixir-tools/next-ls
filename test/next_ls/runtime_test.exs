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

  test "returns the response in an ok tuple", %{logger: logger, cwd: cwd} do
    start_supervised!({Registry, keys: :unique, name: RuntimeTestRegistry})
    pid = start_supervised!({Runtime, working_dir: cwd, parent: logger, extension_registry: RuntimeTestRegistry})

    Process.link(pid)

    assert wait_for_ready(pid)

    assert {:ok, "\"hi\""} = Runtime.call(pid, {Kernel, :inspect, ["hi"]})
  end

  test "call returns an error when the runtime is node ready", %{logger: logger, cwd: cwd} do
    start_supervised!({Registry, keys: :unique, name: RuntimeTestRegistry})
    pid = start_supervised!({Runtime, working_dir: cwd, parent: logger, extension_registry: RuntimeTestRegistry})

    Process.link(pid)

    assert {:error, :not_ready} = Runtime.call(pid, {IO, :puts, ["hi"]})
  end

  test "compiles the code and returns diagnostics", %{logger: logger, cwd: cwd} do
    start_supervised!({Registry, keys: :unique, name: RuntimeTestRegistry})

    capture_log(fn ->
      pid = start_supervised!({Runtime, working_dir: cwd, parent: logger, extension_registry: RuntimeTestRegistry})

      Process.link(pid)

      assert wait_for_ready(pid)

      file = Path.join(cwd, "lib/bar.ex")

      assert [
               %Mix.Task.Compiler.Diagnostic{
                 file: ^file,
                 severity: :warning,
                 message:
                   "variable \"arg1\" is unused (if the variable is not meant to be used, prefix it with an underscore)",
                 position: position,
                 compiler_name: "Elixir",
                 details: nil
               }
             ] = Runtime.compile(pid)

      if Version.match?(System.version(), ">= 1.15.0") do
        assert position == {4, 11}
      else
        assert position == 4
      end

      File.write!(file, """
      defmodule Bar do
        def foo(arg1) do
          arg1
        end
      end
      """)

      assert [] == Runtime.compile(pid)
    end) =~ "Connected to node"
  end

  defp wait_for_ready(pid) do
    with false <- Runtime.ready?(pid) do
      Process.sleep(100)
      wait_for_ready(pid)
    end
  end
end
