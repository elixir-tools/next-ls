import Config

case System.get_env("NEXTLS_RELEASE_MODE", "plain") do
  "burrito" ->
    config :next_ls, arg_parser: {Burrito.Util.Args, :get_arguments, []}

  "plain" ->
    config :next_ls, arg_parser: {System, :argv, []}
end

if System.get_env("NEXTLS_OTEL") == "1" do
  config :next_ls,
    otel: true

  config :opentelemetry_exporter,
    otlp_protocol: :grpc,
    otlp_endpoint: "http://localhost:4317"
else
  config :opentelemetry, traces_exporter: :none
end
