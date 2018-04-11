defmodule FetchFavicon.MixProject do
  use Mix.Project

  def project do
    [
      app: :fetch_favicon,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # HTTP Client
      {:httpoison, "~> 1.0"},
      # HTML Parser
      {:floki, "~> 0.20.0"},
      # For testing
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
