defmodule MessageStore.MixProject do
  use Mix.Project

  def project do
    [
      app: :message_store,
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: "dialyzer.ignore-warnings",
        flags: [
          :unmatched_returns,
          :error_handling,
          :race_conditions,
          :no_opaque
        ]
      ],
      version: "2.4.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "An useful extensions for eventstore.",
      deps: deps(),
      source_url: "https://github.com/catchcake/message_store",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:excoveralls, "~> 0.14", only: :test},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:eventstore, "1.2.1"},
      {:jason, "~> 1.2"},
      {:result, "~> 1.6"},
      {:ex_maybe, "~> 1.1"}
    ]
  end

  defp package do
    [
      maintainers: [
        "Jindrich K. Smitka <smitka.j@gmail.com>",
        "Daniel Bultas <comm3net@gmail.com>"
      ],
      licenses: ["BSD-4-Clause"],
      links: %{
        "GitHub" => "https://github.com/catchcake/message_store"
      }
    ]
  end

  defp aliases() do
    [
      "event_store.setup": ["event_store.create", "event_store.init", "event_store.migrate"],
      "event_store.reset": ["event_store.drop", "event_store.setup"],
      test: ["event_store.drop", "event_store.setup", "test"]
    ]
  end
end
