defmodule B1tpoti0n.MixProject do
  use Mix.Project

  def project do
    [
      app: :b1tpoti0n,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {B1tpoti0n.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Database (SQLite and PostgreSQL supported)
      {:ecto_sql, "~> 3.11"},
      {:ecto_sqlite3, "~> 0.17"},
      {:postgrex, "~> 0.19"},

      # HTTP Server
      {:bandit, "~> 1.2"},
      {:plug, "~> 1.15"},
      {:websock_adapter, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Telemetry & Metrics
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # Clustering
      {:libcluster, "~> 3.3"},
      {:horde, "~> 0.9"},

      # External cache (optional)
      {:redix, "~> 1.5"},

      # Dev & Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
