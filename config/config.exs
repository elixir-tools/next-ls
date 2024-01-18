import Config

config :next_ls, :indexing_timeout, 100

import_config "#{config_env()}.exs"
