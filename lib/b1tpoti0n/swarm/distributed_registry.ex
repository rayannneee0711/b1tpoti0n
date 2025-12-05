defmodule B1tpoti0n.Swarm.DistributedRegistry do
  @moduledoc """
  Distributed registry for swarm workers using Horde.

  When clustering is enabled, uses Horde.Registry for distributed
  process registration. Otherwise falls back to the standard Registry.
  """
  use Horde.Registry

  def start_link(_opts) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @impl true
  def init(init_arg) do
    [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.Registry.init()
  end

  defp members do
    Enum.map([Node.self() | Node.list()], fn node ->
      {__MODULE__, node}
    end)
  end
end
