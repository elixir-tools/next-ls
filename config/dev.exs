import Config

config :next_ls, :assets, tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}

config :web_dev_utils, :reload_url, "'wss://' + location.host + '/ws'"
config :web_dev_utils, :reload_log, true
