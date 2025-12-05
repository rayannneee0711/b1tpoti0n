defmodule B1tpoti0n.Cluster do
  @moduledoc """
  Cluster configuration and helpers.

  Uses libcluster for automatic node discovery and Horde for
  distributed process supervision.

  ## Configuration

      config :b1tpoti0n, :cluster,
        enabled: true,
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: "0.0.0.0",
          multicast_addr: "230.1.1.251",
          multicast_ttl: 1
        ]

  ## Strategies

  - `Cluster.Strategy.Gossip` - Multicast UDP for local networks
  - `Cluster.Strategy.Epmd` - Erlang Port Mapper Daemon
  - `Cluster.Strategy.Kubernetes` - Kubernetes DNS-based discovery
  - `Cluster.Strategy.DNSPoll` - DNS polling for hostnames
  """

  @doc """
  Returns whether clustering is enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    config = Application.get_env(:b1tpoti0n, :cluster, [])
    Keyword.get(config, :enabled, false)
  end

  @doc """
  Returns the cluster topology configuration for libcluster.
  """
  @spec topology() :: Keyword.t()
  def topology do
    config = Application.get_env(:b1tpoti0n, :cluster, [])
    strategy = Keyword.get(config, :strategy, Cluster.Strategy.Gossip)
    strategy_config = Keyword.get(config, :config, default_gossip_config())

    [
      b1tpoti0n: [
        strategy: strategy,
        config: strategy_config
      ]
    ]
  end

  @doc """
  Returns the list of connected nodes including self.
  """
  @spec nodes() :: [node()]
  def nodes do
    [Node.self() | Node.list()]
  end

  @doc """
  Returns cluster status information.
  """
  @spec status() :: map()
  def status do
    %{
      enabled: enabled?(),
      node: Node.self(),
      connected_nodes: Node.list(),
      total_nodes: length(nodes()),
      alive: Node.alive?()
    }
  end

  defp default_gossip_config do
    [
      port: 45892,
      if_addr: "0.0.0.0",
      multicast_addr: "230.1.1.251",
      multicast_ttl: 1
    ]
  end
end
