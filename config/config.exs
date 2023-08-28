import Config

config :next_ls, :indexing_timeout, 100

config :logger, :default_handler, config: [type: :standard_error]

import_config "#{config_env()}.exs"
