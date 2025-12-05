defmodule B1tpoti0n.Swarm.PeerStorage.Memory do
  @moduledoc """
  In-memory peer storage using ETS.

  Each torrent has its own ETS table for peer storage.
  Tables are created on first access and cleaned up when empty.

  This is the default storage backend for single-node deployments.
  """

  @behaviour B1tpoti0n.Swarm.PeerStorage

  @table_prefix :b1tp_peers_

  @doc """
  Get or create the ETS table for a torrent.
  """
  def ensure_table(info_hash) do
    table_name = table_name(info_hash)

    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

      _ref ->
        table_name
    end
  end

  defp table_name(info_hash) do
    # Use a hash of info_hash for table name (atoms are limited)
    hash = :erlang.phash2(info_hash)
    :"#{@table_prefix}#{hash}"
  end

  @impl true
  def get_peer(info_hash, key) do
    table = ensure_table(info_hash)

    case :ets.lookup(table, key) do
      [{^key, peer_data}] -> peer_data
      [] -> nil
    end
  end

  @impl true
  def put_peer(info_hash, key, peer_data) do
    table = ensure_table(info_hash)
    :ets.insert(table, {key, peer_data})
    :ok
  end

  @impl true
  def delete_peer(info_hash, key) do
    table = ensure_table(info_hash)
    :ets.delete(table, key)
    :ok
  end

  @impl true
  def get_all_peers(info_hash) do
    table = ensure_table(info_hash)

    :ets.tab2list(table)
    |> Map.new(fn {key, data} -> {key, data} end)
  end

  @impl true
  def count_peers(info_hash) do
    table = ensure_table(info_hash)
    :ets.info(table, :size)
  end

  @impl true
  def cleanup_expired(info_hash, cutoff_time) do
    table = ensure_table(info_hash)

    # Find and delete expired peers
    expired =
      :ets.tab2list(table)
      |> Enum.filter(fn {_key, peer} -> peer.updated_at < cutoff_time end)

    Enum.each(expired, fn {key, _} -> :ets.delete(table, key) end)

    length(expired)
  end

  @impl true
  def get_counts(info_hash) do
    table = ensure_table(info_hash)

    :ets.tab2list(table)
    |> Enum.reduce({0, 0}, fn {_key, peer}, {seeders, leechers} ->
      if peer.is_seeder do
        {seeders + 1, leechers}
      else
        {seeders, leechers + 1}
      end
    end)
  end

  @impl true
  def clear(info_hash) do
    table_name = table_name(info_hash)

    case :ets.whereis(table_name) do
      :undefined -> :ok
      _ref -> :ets.delete_all_objects(table_name)
    end

    :ok
  end
end
