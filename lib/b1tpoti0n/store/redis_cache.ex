defmodule B1tpoti0n.Store.RedisCache do
  @moduledoc """
  Redis-backed cache for distributed deployments.

  Provides the same interface as the ETS-based Store.Manager but uses Redis
  for storage, enabling shared state across multiple nodes.

  ## Configuration

      config :b1tpoti0n, :redis,
        enabled: true,
        url: "redis://localhost:6379",
        pool_size: 10

  ## Key Prefixes

  - `b1tp:passkey:{passkey}` - Maps passkey to user_id
  - `b1tp:whitelist:{prefix}` - Client whitelist entries
  - `b1tp:banned:{ip}` - Banned IPs with expiry
  - `b1tp:rate:{ip}:{bucket}` - Rate limit counters
  """
  use GenServer
  require Logger

  @key_prefix "b1tp:"
  @passkey_prefix "#{@key_prefix}passkey:"
  @whitelist_prefix "#{@key_prefix}whitelist:"
  @banned_prefix "#{@key_prefix}banned:"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if Redis cache is enabled and connected.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    config = Application.get_env(:b1tpoti0n, :redis, [])
    Keyword.get(config, :enabled, false) and Process.whereis(__MODULE__) != nil
  end

  @doc """
  Check if Redis is connected.
  """
  @spec connected?() :: boolean()
  def connected? do
    case Process.whereis(__MODULE__) do
      nil -> false
      _pid -> GenServer.call(__MODULE__, :ping) == :ok
    end
  end

  @doc """
  Look up a user_id by passkey.
  """
  @spec lookup_passkey(String.t()) :: {:ok, integer()} | :error
  def lookup_passkey(passkey) do
    case command(["GET", "#{@passkey_prefix}#{passkey}"]) do
      {:ok, nil} -> :error
      {:ok, user_id} -> {:ok, String.to_integer(user_id)}
      {:error, _} -> :error
    end
  end

  @doc """
  Cache a passkey -> user_id mapping.
  """
  @spec cache_passkey(String.t(), integer()) :: :ok | {:error, term()}
  def cache_passkey(passkey, user_id) do
    case command(["SET", "#{@passkey_prefix}#{passkey}", to_string(user_id)]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Remove a passkey from cache.
  """
  @spec remove_passkey(String.t()) :: :ok
  def remove_passkey(passkey) do
    command(["DEL", "#{@passkey_prefix}#{passkey}"])
    :ok
  end

  @doc """
  Check if a client prefix is whitelisted.
  """
  @spec valid_client?(String.t()) :: boolean()
  def valid_client?(peer_id) when is_binary(peer_id) do
    prefix = binary_part(peer_id, 0, min(8, byte_size(peer_id)))

    case command(["EXISTS", "#{@whitelist_prefix}#{prefix}"]) do
      {:ok, 1} -> true
      _ -> check_whitelist_patterns(peer_id)
    end
  end

  @doc """
  Add a client prefix to whitelist.
  """
  @spec add_whitelist(String.t(), String.t()) :: :ok | {:error, term()}
  def add_whitelist(prefix, name) do
    case command(["SET", "#{@whitelist_prefix}#{prefix}", name]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Check if an IP is banned.
  """
  @spec ip_banned?(String.t()) :: boolean()
  def ip_banned?(ip) do
    case command(["EXISTS", "#{@banned_prefix}#{ip}"]) do
      {:ok, 1} -> true
      _ -> false
    end
  end

  @doc """
  Ban an IP address with optional expiry.
  """
  @spec ban_ip(String.t(), integer() | nil) :: :ok | {:error, term()}
  def ban_ip(ip, expires_in_seconds \\ nil) do
    key = "#{@banned_prefix}#{ip}"

    result =
      if expires_in_seconds do
        command(["SET", key, "banned", "EX", to_string(expires_in_seconds)])
      else
        command(["SET", key, "banned"])
      end

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Unban an IP address.
  """
  @spec unban_ip(String.t()) :: :ok
  def unban_ip(ip) do
    command(["DEL", "#{@banned_prefix}#{ip}"])
    :ok
  end

  @doc """
  Flush all cache entries.
  """
  @spec flush() :: :ok
  def flush do
    # Get all keys with our prefix
    case command(["KEYS", "#{@key_prefix}*"]) do
      {:ok, keys} when is_list(keys) and length(keys) > 0 ->
        command(["DEL" | keys])

      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: map()
  def stats do
    passkeys =
      case command(["KEYS", "#{@passkey_prefix}*"]) do
        {:ok, keys} -> length(keys)
        _ -> 0
      end

    whitelist =
      case command(["KEYS", "#{@whitelist_prefix}*"]) do
        {:ok, keys} -> length(keys)
        _ -> 0
      end

    banned =
      case command(["KEYS", "#{@banned_prefix}*"]) do
        {:ok, keys} -> length(keys)
        _ -> 0
      end

    %{
      passkeys: passkeys,
      whitelist: whitelist,
      banned_ips: banned,
      connected: connected?()
    }
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    config = Application.get_env(:b1tpoti0n, :redis, [])
    url = Keyword.get(config, :url, "redis://localhost:6379")

    case Redix.start_link(url, name: :redix_cache) do
      {:ok, conn} ->
        Logger.info("Redis cache connected: #{url}")
        {:ok, %{conn: conn}}

      {:error, reason} ->
        Logger.error("Redis cache connection failed: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:ping, _from, state) do
    result =
      case Redix.command(:redix_cache, ["PING"]) do
        {:ok, "PONG"} -> :ok
        _ -> :error
      end

    {:reply, result, state}
  end

  # Private

  defp command(args) do
    try do
      Redix.command(:redix_cache, args)
    rescue
      _ -> {:error, :not_connected}
    catch
      :exit, _ -> {:error, :not_connected}
    end
  end

  defp check_whitelist_patterns(peer_id) do
    # Check common prefixes (1-8 chars)
    Enum.any?(1..8, fn len ->
      prefix = binary_part(peer_id, 0, min(len, byte_size(peer_id)))

      case command(["EXISTS", "#{@whitelist_prefix}#{prefix}"]) do
        {:ok, 1} -> true
        _ -> false
      end
    end)
  end
end
