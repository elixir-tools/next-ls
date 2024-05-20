import Config

if System.get_env("NEXTLS_OTEL") == "1" do
  config :next_ls,
    otel: true

  config :opentelemetry_exporter,
    otlp_protocol: :grpc,
    otlp_endpoint: "http://localhost:4317"
else
  config :opentelemetry, traces_exporter: :none
end
