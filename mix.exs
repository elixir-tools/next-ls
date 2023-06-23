defmodule NextLS.MixProject do
  use Mix.Project

  def project do
    [
      app: :next_ls,
      description: "The langauge server for Elixir that just works",
      version: "0.2.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
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
      extra_applications: [:logger],
      mod: {NextLS.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_lsp, "~> 0.2.1"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package() do
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
