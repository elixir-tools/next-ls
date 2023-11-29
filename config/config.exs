import Config

config :next_ls, :indexing_timeout, 100

config :temple,
  engine: EEx.SmartEngine,
  attributes: {Temple, :attributes}

config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
    --config=assets/tailwind.config.js
    --input=assets/css/app.css
    --output=priv/css/site.css
    )
  ]

# config :logger, :default_handler, config: [type: :standard_error]
config :logger, :default_handler,
  config: [
    file: ~c".elixir-tools/next-ls.log",
    filesync_repeat_interval: 5000,
    file_check: 5000,
    max_no_bytes: 10_000_000,
    max_no_files: 5,
    compress_on_rotate: true
  ]

config :logger, :default_formatter, format: "\n$time $metadata[$level] $message\n", metadata: [:id]

config :next_ls, :logger, [
  {:handler, :ui_logger, NextLS.UI.Logger,
   %{
     config: %{},
     formatter: Logger.Formatter.new()
   }}
]

import_config "#{config_env()}.exs"
