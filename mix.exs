defmodule NextLS.MixProject do
  use Mix.Project

  @version "0.9.0" # x-release-please-version

  def project do
    [
      app: :next_ls,
      description: "The language server for Elixir that just works",
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
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"]
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
          targets: [
            darwin_arm64: [os: :darwin, cpu: :aarch64],
            darwin_amd64: [os: :darwin, cpu: :x86_64],
            linux_arm64: [os: :linux, cpu: :aarch64, libc: :gnu],
            linux_amd64: [os: :linux, cpu: :x86_64, libc: :gnu],
            linux_arm64_musl: [os: :linux, cpu: :aarch64, libc: :musl],
            linux_amd64_musl: [os: :linux, cpu: :x86_64, libc: :musl],
            windows_amd64: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_lsp, "~> 0.5"},
      {:exqlite, "~> 0.13.14"},
      {:styler, "~> 0.8", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:burrito, github: "burrito-elixir/burrito"},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Mitchell Hanberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/elixir-tools/next-ls",
        Sponsor: "https://github.com/sponsors/mhanberg"
      },
      files: ~w(lib LICENSE mix.exs priv README.md .formatter.exs)
    ]
  end
end
