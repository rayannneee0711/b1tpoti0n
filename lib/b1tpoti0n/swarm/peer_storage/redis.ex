defmodule B1tpoti0n.Swarm.PeerStorage.Redis do
  @moduledoc """
  Redis-backed peer storage for distributed deployments.

  Stores peers in Redis hashes, one per torrent:
  - Key: `b1tp:peers:{info_hash_hex}`
  - Field: `{ip}:{port}`
  - Value: JSON-encoded peer data

  Peer expiration is handled via a sorted set for each torrent:
  - Key: `b1tp:peers_ts:{info_hash_hex}`
  - Score: updated_at timestamp
  - Member: `{ip}:{port}`

  This enables efficient cleanup of expired peers.

  ## Configuration

      config :b1tpoti0n,
        peer_storage: :redis

      config :b1tpoti0n, :redis,
        enabled: true,
        url: "redis://localhost:6379"
  """

  @behaviour B1tpoti0n.Swarm.PeerStorage

  @peers_prefix "b1tp:peers:"
  @peers_ts_prefix "b1tp:peers_ts:"

  defp hash_key(info_hash) do
    "#{@peers_prefix}#{Base.encode16(info_hash, case: :lower)}"
  end

  defp ts_key(info_hash) do
    "#{@peers_ts_prefix}#{Base.encode16(info_hash, case: :lower)}"
  end

  defp peer_field({ip, port}), do: "#{ip}:#{port}"

  defp parse_peer_field(field) do
    case String.split(field, ":", parts: 2) do
      [ip, port_str] -> {ip, String.to_integer(port_str)}
      _ -> nil
    end
  end

  defp encode_peer(peer_data) do
    # Convert to a serializable format
    peer_data
    |> Map.update(:peer_id, nil, fn
      nil -> nil
      bin when is_binary(bin) -> Base.encode64(bin)
    end)
    |> Jason.encode!()
  end

  defp decode_peer(json) do
    case Jason.decode(json) do
      {:ok, data} ->
        data
        |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.update(:peer_id, nil, fn
          nil -> nil
          b64 -> Base.decode64!(b64)
        end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  @impl true
  def get_peer(info_hash, key) do
    field = peer_field(key)

    case command(["HGET", hash_key(info_hash), field]) do
      {:ok, nil} -> nil
      {:ok, json} -> decode_peer(json)
      {:error, _} -> nil
    end
  end

  @impl true
  def put_peer(info_hash, key, peer_data) do
    field = peer_field(key)
    json = encode_peer(peer_data)
    timestamp = peer_data.updated_at

    # Use pipeline for atomic update
    commands = [
      ["HSET", hash_key(info_hash), field, json],
      ["ZADD", ts_key(info_hash), to_string(timestamp), field]
    ]

    pipeline(commands)
    :ok
  end

  @impl true
  def delete_peer(info_hash, key) do
    field = peer_field(key)

    commands = [
      ["HDEL", hash_key(info_hash), field],
      ["ZREM", ts_key(info_hash), field]
    ]

    pipeline(commands)
    :ok
  end

  @impl true
  def get_all_peers(info_hash) do
    case command(["HGETALL", hash_key(info_hash)]) do
      {:ok, pairs} when is_list(pairs) ->
        pairs
        |> Enum.chunk_every(2)
        |> Enum.reduce(%{}, fn [field, json], acc ->
          case {parse_peer_field(field), decode_peer(json)} do
            {nil, _} -> acc
            {_, nil} -> acc
            {key, peer} -> Map.put(acc, key, peer)
          end
        end)

      _ ->
        %{}
    end
  end

  @impl true
  def count_peers(info_hash) do
    case command(["HLEN", hash_key(info_hash)]) do
      {:ok, count} when is_integer(count) -> count
      _ -> 0
    end
  end

  @impl true
  def cleanup_expired(info_hash, cutoff_time) do
    # Get expired peer fields from sorted set
    case command(["ZRANGEBYSCORE", ts_key(info_hash), "-inf", to_string(cutoff_time)]) do
      {:ok, expired_fields} when is_list(expired_fields) and length(expired_fields) > 0 ->
        # Remove from both hash and sorted set
        commands = [
          ["HDEL", hash_key(info_hash) | expired_fields],
          ["ZREMRANGEBYSCORE", ts_key(info_hash), "-inf", to_string(cutoff_time)]
        ]

        pipeline(commands)
        length(expired_fields)

      _ ->
        0
    end
  end

  @impl true
  def get_counts(info_hash) do
    peers = get_all_peers(info_hash)

    Enum.reduce(peers, {0, 0}, fn {_key, peer}, {seeders, leechers} ->
      if peer[:is_seeder] do
        {seeders + 1, leechers}
      else
        {seeders, leechers + 1}
      end
    end)
  end

  @impl true
  def clear(info_hash) do
    commands = [
      ["DEL", hash_key(info_hash)],
      ["DEL", ts_key(info_hash)]
    ]

    pipeline(commands)
    :ok
  end

  # Redis command helpers

  defp command(args) do
    try do
      Redix.command(:redix_cache, args)
    rescue
      _ -> {:error, :not_connected}
    catch
      :exit, _ -> {:error, :not_connected}
    end
  end

  defp pipeline(commands) do
    try do
      Redix.pipeline(:redix_cache, commands)
    rescue
      _ -> {:error, :not_connected}
    catch
      :exit, _ -> {:error, :not_connected}
    end
  end
end
