defmodule B1tpoti0n.Swarm do
  @moduledoc """
  Unified swarm management interface.

  Automatically selects between local (single-node) and distributed (cluster)
  mode based on configuration. When clustering is enabled, uses Horde for
  distributed supervision and registry.

  ## Configuration

      config :b1tpoti0n, :cluster,
        enabled: true,
        # ... cluster config

  """

  alias B1tpoti0n.Cluster
  alias B1tpoti0n.Swarm.{Supervisor, DistributedSupervisor}

  @doc """
  Get or start a swarm worker for the given info_hash.
  Routes to the appropriate supervisor based on clustering mode.
  """
  @spec get_or_start_worker(binary()) :: {:ok, pid()} | {:error, atom()}
  def get_or_start_worker(info_hash) do
    if Cluster.enabled?() do
      DistributedSupervisor.get_or_start_worker(info_hash)
    else
      Supervisor.get_or_start_worker(info_hash)
    end
  end

  @doc """
  Look up an existing swarm worker.
  """
  @spec lookup_worker(binary()) :: {:ok, pid()} | :error
  def lookup_worker(info_hash) do
    if Cluster.enabled?() do
      DistributedSupervisor.lookup_worker(info_hash)
    else
      Supervisor.lookup_worker(info_hash)
    end
  end

  @doc """
  Get an existing swarm worker without creating one.
  """
  @spec get_worker(binary()) :: {:ok, pid()} | {:error, :not_found}
  def get_worker(info_hash) do
    if Cluster.enabled?() do
      DistributedSupervisor.get_worker(info_hash)
    else
      Supervisor.get_worker(info_hash)
    end
  end

  @doc """
  Stop a swarm worker.
  """
  @spec stop_worker(binary()) :: :ok | {:error, :not_found}
  def stop_worker(info_hash) do
    if Cluster.enabled?() do
      DistributedSupervisor.stop_worker(info_hash)
    else
      Supervisor.stop_worker(info_hash)
    end
  end

  @doc """
  Count active swarm workers.
  """
  @spec count_workers() :: non_neg_integer()
  def count_workers do
    if Cluster.enabled?() do
      DistributedSupervisor.count_workers()
    else
      Supervisor.count_workers()
    end
  end

  @doc """
  List all active info_hashes.
  """
  @spec list_torrents() :: [binary()]
  def list_torrents do
    if Cluster.enabled?() do
      DistributedSupervisor.list_torrents()
    else
      Supervisor.list_torrents()
    end
  end

  @doc """
  List all active swarm workers with their info_hashes.
  """
  @spec list_workers() :: [{binary(), pid()}]
  def list_workers do
    if Cluster.enabled?() do
      DistributedSupervisor.list_workers()
    else
      Supervisor.list_workers()
    end
  end

  @doc """
  Get swarm status information.
  """
  @spec status() :: map()
  def status do
    %{
      mode: if(Cluster.enabled?(), do: :distributed, else: :local),
      active_workers: count_workers(),
      active_torrents: length(list_torrents())
    }
  end
end
