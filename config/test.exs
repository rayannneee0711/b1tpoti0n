import Config

config :b1tpoti0n, B1tpoti0n.Persistence.Repo,
  database: Path.expand("../priv/b1tpoti0n_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox

config :b1tpoti0n,
  http_port: 18080,
  udp_port: 18081,
  admin_token: "test_admin_token_12345"

config :logger, level: :warning
