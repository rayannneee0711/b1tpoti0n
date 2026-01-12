import Config

if config_env() == :prod do
  config :b1tpoti0n,
    http_port: String.to_integer(System.get_env("HTTP_PORT") || "8080"),
    # HTTPS configuration via environment variables
    https_port:
      if(https_port = System.get_env("HTTPS_PORT"),
        do: String.to_integer(https_port),
        else: nil
      ),
    https_certfile: System.get_env("TLS_CERT_PATH"),
    https_keyfile: System.get_env("TLS_KEY_PATH"),
    https_only: System.get_env("HTTPS_ONLY") == "true",
    # UDP tracker configuration (BEP 15)
    udp_port:
      if(udp_port = System.get_env("UDP_PORT"),
        do: String.to_integer(udp_port),
        else: nil
      ),
    udp_connection_timeout:
      String.to_integer(System.get_env("UDP_CONNECTION_TIMEOUT") || "120"),
    # Admin token for API authentication
    admin_token: System.get_env("ADMIN_TOKEN"),
    # CORS origins (comma-separated for multiple, "*" for all)
    cors_origins:
      (case System.get_env("CORS_ORIGINS") do
        nil -> "*"
        "*" -> "*"
        origins -> String.split(origins, ",", trim: true)
      end),
    # IP whitelist for Admin API (comma-separated, empty = no restriction)
    admin_api_ip_whitelist:
      (case System.get_env("ADMIN_API_IP_WHITELIST") do
        nil -> []
        "" -> []
        ips -> String.split(ips, ",", trim: true) |> Enum.map(&String.trim/1)
      end)

  # Database configuration
  # For SQLite: set DATABASE_PATH
  # For PostgreSQL: set DATABASE_URL or individual PG_* variables
  repo_config =
    if database_url = System.get_env("DATABASE_URL") do
      # PostgreSQL via URL
      [
        url: database_url,
        pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")
      ]
    else
      # SQLite (default) or PostgreSQL via individual vars
      case System.get_env("DATABASE_ADAPTER") do
        "postgresql" ->
          [
            hostname: System.get_env("PG_HOST") || "localhost",
            port: String.to_integer(System.get_env("PG_PORT") || "5432"),
            database: System.get_env("PG_DATABASE") || "b1tpoti0n",
            username: System.get_env("PG_USER") || "postgres",
            password: System.get_env("PG_PASSWORD"),
            pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")
          ]

        _ ->
          # SQLite
          [
            database: System.get_env("DATABASE_PATH") || "/var/lib/b1tpoti0n/tracker.db",
            pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
          ]
      end
    end

  config :b1tpoti0n, B1tpoti0n.Persistence.Repo, repo_config
end
