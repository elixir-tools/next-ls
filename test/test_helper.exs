{:ok, _pid} = Node.start(:"nextls#{System.system_time()}", :shortnames)

Logger.configure(level: :warning)

timeout =
  if System.get_env("CI", "false") == "true" do
    60_000
  else
    30_000
  end

ExUnit.start(
  exclude: [pending: true],
  assert_receive_timeout: timeout,
  timeout: 120_000
)
