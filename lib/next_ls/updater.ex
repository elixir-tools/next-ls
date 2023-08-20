defmodule NextLS.Updater do
  @moduledoc false
  use Task

  def start_link(arg \\ []) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(opts) do
    Logger.put_module_level(Req.Steps, :none)

    binpath = Keyword.get(opts, :binpath, Path.expand("~/.cache/elixir-tools/nextls/bin/nextls"))
    api_host = Keyword.get(opts, :api_host, "https://api.github.com")
    github_host = Keyword.get(opts, :github_host, "https://github.com")
    logger = Keyword.fetch!(opts, :logger)
    current_version = Keyword.fetch!(opts, :current_version)
    retry = Keyword.get(opts, :retry, :safe)

    case Req.get("/repos/elixir-tools/next-ls/releases/latest", base_url: api_host, retry: retry) do
      {:ok, %{body: %{"tag_name" => "v" <> version = tag}}} ->
        with {:ok, latest_version} <- Version.parse(version),
             :gt <- Version.compare(latest_version, current_version) do
          with :ok <- File.rename(binpath, binpath <> "-#{Version.to_string(current_version)}"),
               {:ok, _} <-
                 File.open(binpath, [:write], fn file ->
                   fun = fn request, finch_request, finch_name, finch_options ->
                     fun = fn
                       {:status, status}, response ->
                         %{response | status: status}

                       {:headers, headers}, response ->
                         %{response | headers: headers}

                       {:data, data}, response ->
                         IO.binwrite(file, data)
                         response
                     end

                     case Finch.stream(finch_request, finch_name, Req.Response.new(), fun, finch_options) do
                       {:ok, response} -> {request, response}
                       {:error, exception} -> {request, exception}
                     end
                   end

                   with {:error, error} <-
                          Req.get("/elixir-tools/next-ls/releases/download/#{tag}/next_ls_#{os()}_#{arch()}",
                            finch_request: fun,
                            base_url: github_host,
                            retry: retry
                          ) do
                     NextLS.Logger.show_message(logger, :error, "Failed to download version #{version} of Next LS!")
                     NextLS.Logger.error(logger, "Failed to download Next LS: #{inspect(error)}")
                     :error
                   end
                 end) do
            File.chmod(binpath, 0o755)

            NextLS.Logger.show_message(logger, :info, "Downloaded #{version} of Next LS!")
            NextLS.Logger.info(logger, "Downloaded #{version} of Next LS!")
          end
        end

      {:error, error} ->
        NextLS.Logger.error(
          logger,
          "Failed to retrieve the latest version number of Next LS from the GitHub API: #{inspect(error)}"
        )
    end
  end

  defp arch do
    arch_str = :erlang.system_info(:system_architecture)
    [arch | _] = arch_str |> List.to_string() |> String.split("-")

    case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
      {{:win32, _}, _arch, 64} -> :amd64
      {_os, arch, 64} when arch in ~w(arm aarch64) -> :arm64
      {_os, arch, 64} when arch in ~w(amd64 x86_64) -> :amd64
      {os, arch, _wordsize} -> raise "Unsupported system: os=#{inspect(os)}, arch=#{inspect(arch)}"
    end
  end

  defp os do
    case :os.type() do
      {:win32, _} -> :windows
      {:unix, :darwin} -> :darwin
      {:unix, :linux} -> :linux
      unknown_os -> raise "Unsupported system: os=#{inspect(unknown_os)}}"
    end
  end
end
