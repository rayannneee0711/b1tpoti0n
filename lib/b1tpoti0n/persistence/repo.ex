defmodule B1tpoti0n.Persistence.Repo do
  @moduledoc """
  Ecto repository for B1tpoti0n tracker.

  Supports both SQLite3 and PostgreSQL adapters, configured via:

      config :b1tpoti0n, B1tpoti0n.Persistence.Repo,
        adapter: Ecto.Adapters.SQLite3  # or Ecto.Adapters.Postgres

  SQLite is the default for simple single-node deployments.
  PostgreSQL is recommended for high-traffic or clustered deployments.
  """

  @adapter Application.compile_env(
             :b1tpoti0n,
             [B1tpoti0n.Persistence.Repo, :adapter],
             Ecto.Adapters.SQLite3
           )

  use Ecto.Repo,
    otp_app: :b1tpoti0n,
    adapter: @adapter
end
