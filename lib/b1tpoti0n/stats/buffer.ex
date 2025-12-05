defmodule B1tpoti0n.Stats.Buffer do
  @moduledoc """
  Aggregates upload/download statistics before batch writing to database.
  Uses ETS for lock-free counter updates with write_concurrency.

  This allows the network layer to record stats without blocking on DB writes.
  The Collector process periodically flushes these stats to the database.
  """
  use GenServer
  require Logger

  @table :b1tpoti0n_stats_buffer

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Increment upload/download counters for a user.
  This is a fast, non-blocking operation using ETS atomic counters.

  ## Parameters
  - user_id: The user's database ID (can be nil for anonymous tracking)
  - uploaded: Bytes uploaded delta
  - downloaded: Bytes downloaded delta
  """
  @spec record_transfer(integer() | nil, non_neg_integer(), non_neg_integer()) :: :ok
  def record_transfer(nil, _uploaded, _downloaded), do: :ok

  def record_transfer(user_id, uploaded, downloaded) do
    key = {:user, user_id}

    # Use update_counter with default value if key doesn't exist
    # Format: {key, uploaded, downloaded}
    :ets.update_counter(
      @table,
      key,
      [
        {2, uploaded},
        {3, downloaded}
      ],
      {key, 0, 0}
    )

    :ok
  end

  @doc """
  Record torrent activity (seeder/leecher counts).
  Called periodically or on significant changes.
  """
  @spec record_torrent_stats(integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def record_torrent_stats(torrent_id, seeders, leechers) do
    :ets.insert(@table, {{:torrent, torrent_id}, seeders, leechers})
    :ok
  end

  @doc """
  Flush all buffered stats and return them.
  Called by Collector for batch DB writes.

  ## Returns
  A map with :users and :torrents keys containing lists of stats.
  """
  @spec flush() :: %{users: list(), torrents: list()}
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Get current buffer size (number of entries).
  """
  @spec size() :: non_neg_integer()
  def size do
    :ets.info(@table, :size)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :set,
      :named_table,
      :public,
      write_concurrency: true
    ])

    Logger.info("Stats buffer initialized")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    # Get all entries and clear table atomically
    entries = :ets.tab2list(@table)
    :ets.delete_all_objects(@table)

    # Separate user and torrent stats
    {user_stats, torrent_stats} =
      Enum.split_with(entries, fn
        {{:user, _}, _, _} -> true
        _ -> false
      end)

    result = %{
      users:
        Enum.map(user_stats, fn {{:user, id}, up, down} ->
          %{user_id: id, uploaded: up, downloaded: down}
        end),
      torrents:
        Enum.map(torrent_stats, fn {{:torrent, id}, s, l} ->
          %{torrent_id: id, seeders: s, leechers: l}
        end)
    }

    {:reply, result, state}
  end
end
