defmodule B1tpoti0n.Stats.Collector do
  @moduledoc """
  Periodic collector that flushes buffered stats to the database.
  Uses batch upserts for efficient database writes.
  """
  use GenServer
  require Logger

  alias B1tpoti0n.Stats.Buffer
  alias B1tpoti0n.Persistence.Repo

  # Flush interval: every 10 seconds
  @flush_interval_ms 10_000

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Force an immediate flush of stats to the database.
  Useful for graceful shutdown.
  """
  @spec force_flush() :: :ok
  def force_flush do
    GenServer.call(__MODULE__, :force_flush)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    schedule_flush()
    Logger.info("Stats collector started, flushing every #{@flush_interval_ms}ms")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:force_flush, _from, state) do
    do_flush()
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:flush, state) do
    do_flush()
    schedule_flush()
    {:noreply, state}
  end

  # --- Private Helpers ---

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end

  defp do_flush do
    stats = Buffer.flush()

    if length(stats.users) > 0 do
      flush_user_stats(stats.users)
    end

    if length(stats.torrents) > 0 do
      flush_torrent_stats(stats.torrents)
    end
  end

  defp flush_user_stats(user_stats) do
    # Batch update user stats using raw SQL for efficiency
    # SQLite doesn't support ON CONFLICT UPDATE as elegantly as PostgreSQL,
    # so we use INSERT OR REPLACE or multiple UPDATE statements

    Enum.each(user_stats, fn %{user_id: user_id, uploaded: uploaded, downloaded: downloaded} ->
      try do
        Repo.query!(
          """
          UPDATE users
          SET uploaded = uploaded + ?,
              downloaded = downloaded + ?,
              updated_at = datetime('now')
          WHERE id = ?
          """,
          [uploaded, downloaded, user_id]
        )
      rescue
        e ->
          Logger.warning("Failed to update user stats for #{user_id}: #{inspect(e)}")
      end
    end)

    if length(user_stats) > 0 do
      Logger.debug("Flushed stats for #{length(user_stats)} users")
    end
  end

  defp flush_torrent_stats(torrent_stats) do
    Enum.each(torrent_stats, fn %{torrent_id: torrent_id, seeders: seeders, leechers: leechers} ->
      try do
        Repo.query!(
          """
          UPDATE torrents
          SET seeders = ?,
              leechers = ?,
              updated_at = datetime('now')
          WHERE id = ?
          """,
          [seeders, leechers, torrent_id]
        )
      rescue
        e ->
          Logger.warning("Failed to update torrent stats for #{torrent_id}: #{inspect(e)}")
      end
    end)

    if length(torrent_stats) > 0 do
      Logger.debug("Flushed stats for #{length(torrent_stats)} torrents")
    end
  end
end
