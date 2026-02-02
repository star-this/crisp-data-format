defmodule Crisp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/star-this/crisp-data-format"

  def project do
    [
      app: :crisp,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Crisp",
      source_url: @source_url,
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
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
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp description do
    """
    CRISP (Clear Readable Interchange for Structured Prose) parser and encoder.
    A human-agent collaborative format combining structured data, prose, and tables.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Specification" => "#{@source_url}/blob/main/SPEC.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE SPEC.md CHEATSHEET.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "SPEC.md", "CHEATSHEET.md"],
      source_ref: "v#{@version}"
    ]
  end
end
