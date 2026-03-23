defmodule SearchTantivy.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/badbeta/search_tantivy"

  def project do
    [
      app: :search_tantivy,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]],
      preferred_cli_env: [
        dialyzer: :dev,
        credo: :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.37.2", runtime: false},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "SearchTantivy",
      source_url: @source_url,
      extras: [
        "guides/getting_started.md",
        "guides/api_guide.md",
        "guides/examples.md",
        "guides/llm_guide.md"
      ]
    ]
  end
end
