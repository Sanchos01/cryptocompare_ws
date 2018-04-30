defmodule CryptocompareWs.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cryptocompare_ws,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CryptocompareWs, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gun, github: "ninenines/gun"},
      {:poison, "~> 3.1"},
    ]
  end
end
