defmodule NextLs.RuntimeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import NextLS.Support.Utils

  alias NextLS.Runtime

  require Logger

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "mix.exs"), mix_exs())
    File.mkdir_p!(Path.join(tmp_dir, "lib"))

    File.write!(Path.join(tmp_dir, "lib/bar.ex"), """
    defmodule Bar do
      defstruct [:foo]

      def foo(arg1) do
      end
    end
    """)

    {:ok, logger} =
      Task.start_link(fn ->
        recv = fn recv ->
          receive do
            msg ->
              Logger.debug(inspect(msg))
          end

          recv.(recv)
        end

        recv.(recv)
      end)

    me = self()

    on_init = fn _ -> send(me, :ready) end

    [logger: logger, cwd: Path.absname(tmp_dir), on_init: on_init]
  end

  test "returns the response in an ok tuple", %{logger: logger, cwd: cwd, on_init: on_init} do
    start_supervised!({Registry, keys: :duplicate, name: RuntimeTest.Registry})
    tvisor = start_supervised!(Task.Supervisor)

    pid =
      start_supervised!(
        {Runtime,
         name: "my_proj",
         on_initialized: on_init,
         task_supervisor: tvisor,
         working_dir: cwd,
         uri: "file://#{cwd}",
         parent: self(),
         logger: logger,
         registry: RuntimeTest.Registry}
      )

    Process.link(pid)

    assert wait_for_ready()

    assert {:ok, "\"hi\""} = Runtime.call(pid, {Kernel, :inspect, ["hi"]})
  end

  test "call returns an error when the runtime is node ready", %{logger: logger, cwd: cwd, on_init: on_init} do
    start_supervised!({Registry, keys: :duplicate, name: RuntimeTest.Registry})

    tvisor = start_supervised!(Task.Supervisor)

    pid =
      start_supervised!(
        {Runtime,
         task_supervisor: tvisor,
         name: "my_proj",
         on_initialized: on_init,
         working_dir: cwd,
         uri: "file://#{cwd}",
         parent: self(),
         logger: logger,
         registry: RuntimeTest.Registry}
      )

    Process.link(pid)

    assert {:error, :not_ready} = Runtime.call(pid, {IO, :puts, ["hi"]})
  end

  test "compiles the code and returns diagnostics", %{logger: logger, cwd: cwd, on_init: on_init} do
    start_supervised!({Registry, keys: :duplicate, name: RuntimeTest.Registry})

    tvisor = start_supervised!(Task.Supervisor)

    capture_log(fn ->
      pid =
        start_supervised!(
          {Runtime,
           name: "my_proj",
           on_initialized: on_init,
           task_supervisor: tvisor,
           working_dir: cwd,
           uri: "file://#{cwd}",
           parent: self(),
           logger: logger,
           registry: RuntimeTest.Registry}
        )

      Process.link(pid)

      assert wait_for_ready()

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

  defp wait_for_ready do
    receive do
      :ready -> true
    after
      10_000 ->
        false
    end
  end
end
