import Config

config :b1tpoti0n, B1tpoti0n.Persistence.Repo,
  database: Path.expand("../priv/b1tpoti0n_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :logger, level: :info
