import Config

config :next_ls, :indexing_timeout, 100

case System.get_env("NEXTLS_RELEASE_MODE", "plain") do
  "burrito" ->
    config :next_ls, arg_parser: {Burrito.Util.Args, :get_arguments, []}

  "plain" ->
    config :next_ls, arg_parser: {System, :argv, []}
end

import_config "#{config_env()}.exs"
