defmodule JTD.MixProject do
  use Mix.Project

  @source_url "https://github.com/nobuyo/json-typedef-elixir"
  @version "0.1.0"

  def project do
    [
      app: :jtd,
      version: @version,
      elixir: "~> 1.11",
      deps: deps(),
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Elixir implementation of JSON Type Definition validation.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Nobuo Takizawa"],
      links: %{
        "GitHub" => @source_url,
        "RFC" => "https://www.rfc-editor.org/rfc/rfc8927.html"
      }
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
    ]
  end
end
