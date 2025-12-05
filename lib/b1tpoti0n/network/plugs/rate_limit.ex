defmodule B1tpoti0n.Network.Plugs.RateLimit do
  @moduledoc """
  Plug for rate limiting HTTP requests.

  ## Usage

      plug B1tpoti0n.Network.Plugs.RateLimit, limit_type: :announce

  Returns 429 Too Many Requests when rate limit is exceeded.
  """
  import Plug.Conn
  alias B1tpoti0n.Network.RateLimiter

  @behaviour Plug

  @impl true
  def init(opts) do
    limit_type = Keyword.get(opts, :limit_type, :announce)
    %{limit_type: limit_type}
  end

  @impl true
  def call(conn, %{limit_type: limit_type}) do
    # Skip if rate limiting is disabled
    if Application.get_env(:b1tpoti0n, :rate_limiting_enabled, true) do
      ip = get_client_ip(conn)

      case RateLimiter.check(ip, limit_type) do
        :ok ->
          conn

        {:error, :rate_limited, retry_after_ms} ->
          retry_after_seconds = div(retry_after_ms, 1000) + 1

          conn
          |> put_resp_header("retry-after", to_string(retry_after_seconds))
          |> put_resp_content_type("text/plain")
          |> send_resp(429, "Rate limit exceeded. Retry after #{retry_after_seconds} seconds.")
          |> halt()
      end
    else
      conn
    end
  end

  defp get_client_ip(conn) do
    # Check X-Forwarded-For first (for proxied requests)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to remote IP
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
