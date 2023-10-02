defmodule NextLS.MixProject do
  use Mix.Project

  @version "0.14.0" # x-release-please-version

  def project do
    [
      app: :next_ls,
      description: "The language server for Elixir that just works. No longer published to Hex, please see our GitHub Releases for downloads.",
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      package: package(),
      deps: deps(),
      docs: [
        # The main page in the docs
        main: "README",
        extras: ["README.md"]
      ],
      dialyzer: [
        plt_core_path: "priv/plts",
        plt_local_path: "priv/plts",
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {NextLS.Application, []}
    ]
  end

  def releases do
    [
      next_ls: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: inject_custom_erts([
            darwin_arm64: [os: :darwin, cpu: :aarch64],
            darwin_amd64: [os: :darwin, cpu: :x86_64],
            linux_arm64: [os: :linux, cpu: :aarch64, libc: :gnu],
            linux_amd64: [os: :linux, cpu: :x86_64, libc: :gnu],
            linux_arm64_musl: [os: :linux, cpu: :aarch64, libc: :musl],
            linux_amd64_musl: [os: :linux, cpu: :x86_64, libc: :musl],
            windows_amd64: [os: :windows, cpu: :x86_64]
          ])
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exqlite, "~> 0.13.14"},
      {:gen_lsp, "~> 0.6"},
      {:req, "~> 0.3.11"},
      {:schematic, "~> 0.2"},

      {:burrito, github: "burrito-elixir/burrito", only: [:dev, :prod]},
      {:bypass, "~> 2.1", only: :test},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:styler, "~> 0.8", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Mitchell Hanberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/elixir-tools/next-ls",
        Sponsor: "https://github.com/sponsors/mhanberg",
        Downloads: "https://github.com/elixir-tools/next-ls/releases"
      },
      files: ~w(lib LICENSE mix.exs priv README.md .formatter.exs)
    ]
  end

  defp inject_custom_erts(targets) do
    # By default, Burrito downloads ERTS from https://burrito-otp.b-cdn.net.
    # When building with Nix, side-effects like network access are not allowed,
    # so we need to inject our own ERTS path.

    erts_path = System.get_env("BURRITO_ERTS_PATH", "")

    Enum.map(targets, fn {target_name, target_conf} ->
      case erts_path do
        "" -> {target_name, target_conf}
        path -> {target_name, [{:custom_erts, path} | target_conf]}
      end
    end)
  end
end
