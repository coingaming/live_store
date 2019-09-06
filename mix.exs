defmodule LiveStore.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :live_store,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      description: """
      Share reactive state across nested LiveView's
      """
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  defp docs do
    [
      main: "LiveStore",
      source_ref: "v#{@version}",
      source_url: "https://github.com/coingaming/live_store"
    ]
  end

  defp package do
    [
      maintainers: ["Reio Piller"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/coingaming/live_store"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end
end
