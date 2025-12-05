defmodule B1tpoti0n.Swarm.Supervisor do
  @moduledoc """
  Dynamic supervisor for swarm workers.
  Creates workers on-demand when a torrent is announced.
  Auto-creates torrent DB records unless whitelist mode is enabled.
  """
  use DynamicSupervisor
  require Logger

  alias B1tpoti0n.Swarm.Worker
  alias B1tpoti0n.Torrents

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Get the PID of an existing swarm worker, or start a new one.
  Uses Registry for O(1) lookup.

  Returns {:ok, pid} or {:error, :not_registered} if torrent whitelist is enforced.
  """
  @spec get_or_start_worker(binary()) :: {:ok, pid()} | {:error, :not_registered}
  def get_or_start_worker(info_hash) when byte_size(info_hash) == 20 do
    case lookup_worker(info_hash) do
      {:ok, pid} ->
        {:ok, pid}

      :error ->
        # Get or create torrent in DB
        case Torrents.get_or_create(info_hash) do
          {:ok, torrent} ->
            case start_worker(info_hash, torrent.id) do
              {:ok, pid} ->
                {:ok, pid}

              {:error, {:already_started, pid}} ->
                # Race condition: another process started the worker
                {:ok, pid}

              {:error, reason} ->
                Logger.error("Failed to start swarm worker: #{inspect(reason)}")
                {:error, :worker_start_failed}
            end

          {:error, :not_registered} ->
            {:error, :not_registered}
        end
    end
  end

  @doc """
  Look up an existing swarm worker by info_hash.
  """
  @spec lookup_worker(binary()) :: {:ok, pid()} | :error
  def lookup_worker(info_hash) do
    case Registry.lookup(B1tpoti0n.Swarm.Registry, info_hash) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Get an existing swarm worker without creating one.
  Returns {:ok, pid} or {:error, :not_found}.
  """
  @spec get_worker(binary()) :: {:ok, pid()} | {:error, :not_found}
  def get_worker(info_hash) do
    case lookup_worker(info_hash) do
      {:ok, pid} -> {:ok, pid}
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Start a new swarm worker for the given info_hash and torrent_id.
  """
  @spec start_worker(binary(), integer()) :: DynamicSupervisor.on_start_child()
  def start_worker(info_hash, torrent_id) do
    spec = {Worker, {info_hash, torrent_id}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Stop a swarm worker.
  """
  @spec stop_worker(binary()) :: :ok | {:error, :not_found}
  def stop_worker(info_hash) do
    case lookup_worker(info_hash) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        :ok

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Get the count of active swarm workers.
  """
  @spec count_workers() :: non_neg_integer()
  def count_workers do
    DynamicSupervisor.count_children(__MODULE__)[:active]
  end

  @doc """
  List all active info_hashes.
  """
  @spec list_torrents() :: [binary()]
  def list_torrents do
    Registry.select(B1tpoti0n.Swarm.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  List all active swarm workers with their info_hashes.
  Returns a list of {info_hash, pid} tuples.
  """
  @spec list_workers() :: [{binary(), pid()}]
  def list_workers do
    Registry.select(B1tpoti0n.Swarm.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end
end
