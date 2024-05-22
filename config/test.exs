import Config

config :gen_lsp, :exit_on_end, false

config :logger, :default_handler, config: [type: :standard_error]
