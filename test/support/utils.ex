defmodule NextLS.Support.Utils do
  def mix_exs do
    """
    defmodule Project.MixProject do
      use Mix.Project

      def project do
        [
          app: :project,
          version: "0.1.0",
          elixir: "~> 1.10",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      # Run "mix help compile.app" to learn about applications.
      def application do
        [
          extra_applications: [:logger]
        ]
      end

      # Run "mix help deps" to learn about dependencies.
      defp deps do
        []
      end
    end
    """
  end
end
