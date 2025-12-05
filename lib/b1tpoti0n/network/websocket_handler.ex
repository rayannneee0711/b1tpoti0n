defmodule B1tpoti0n.Network.WebSocketHandler do
  @moduledoc """
  WebSocket handler for real-time tracker updates.

  Provides live streaming of tracker events to connected clients
  (admin dashboards, monitoring tools).

  ## Events

  Clients receive JSON messages with the following event types:
  - `stats` - Periodic stats updates (every 5 seconds)
  - `announce` - New peer announcements (if subscribed)
  - `swarm` - Swarm creation/termination events

  ## Authentication

  Clients must provide a valid admin token in the connection query string:
  `ws://host/ws?token=YOUR_ADMIN_TOKEN`

  ## Example Client

      const ws = new WebSocket('ws://localhost:8080/ws?token=admin123');
      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        console.log(data.type, data.payload);
      };
  """
  @behaviour WebSock

  require Logger

  @valid_events [:stats, :announce, :swarm]

  alias B1tpoti0n.Admin
  alias B1tpoti0n.Swarm
  alias B1tpoti0n.Cluster

  # Stats broadcast interval
  @stats_interval 5_000

  # Registry for connected WebSocket clients
  def registry_name, do: B1tpoti0n.WebSocket.Registry

  @doc """
  Broadcast a message to all connected WebSocket clients.
  """
  @spec broadcast(map()) :: :ok
  def broadcast(message) do
    Registry.dispatch(registry_name(), :clients, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:broadcast, message})
      end
    end)

    :ok
  end

  @doc """
  Get count of connected WebSocket clients.
  """
  @spec client_count() :: non_neg_integer()
  def client_count do
    Registry.count(registry_name())
  end

  # WebSock Callbacks

  @impl WebSock
  def init(opts) do
    # Register this process with the WebSocket registry
    Registry.register(registry_name(), :clients, %{})

    # Start periodic stats updates
    schedule_stats()

    subscriptions = Keyword.get(opts, :subscriptions, [:stats])

    Logger.info("WebSocket client connected (subscriptions: #{inspect(subscriptions)})")

    {:ok, %{subscriptions: subscriptions}}
  end

  @impl WebSock
  def handle_in({text, [opcode: :text]}, state) do
    case Jason.decode(text) do
      {:ok, %{"type" => "subscribe", "events" => events}} when is_list(events) ->
        valid = parse_events(events)
        new_subs = Enum.uniq(state.subscriptions ++ valid)
        {:ok, %{state | subscriptions: new_subs}}

      {:ok, %{"type" => "unsubscribe", "events" => events}} when is_list(events) ->
        valid = parse_events(events)
        new_subs = Enum.reject(state.subscriptions, &(&1 in valid))
        {:ok, %{state | subscriptions: new_subs}}

      {:ok, %{"type" => "ping"}} ->
        reply = Jason.encode!(%{type: "pong", timestamp: DateTime.utc_now()})
        {:push, {:text, reply}, state}

      {:ok, %{"type" => "get_stats"}} ->
        stats = build_stats()
        reply = Jason.encode!(%{type: "stats", payload: stats})
        {:push, {:text, reply}, state}

      {:ok, %{"type" => "get_swarms"}} ->
        swarms = build_swarm_list()
        reply = Jason.encode!(%{type: "swarms", payload: swarms})
        {:push, {:text, reply}, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_in({_data, [opcode: :binary]}, state) do
    # Ignore binary messages
    {:ok, state}
  end

  @impl WebSock
  def handle_info(:send_stats, state) do
    if :stats in state.subscriptions do
      stats = build_stats()
      message = Jason.encode!(%{type: "stats", payload: stats})
      schedule_stats()
      {:push, {:text, message}, state}
    else
      schedule_stats()
      {:ok, state}
    end
  end

  def handle_info({:broadcast, message}, state) do
    event_type = Map.get(message, :type, :unknown) |> to_atom()

    if event_type in state.subscriptions do
      json = Jason.encode!(message)
      {:push, {:text, json}, state}
    else
      {:ok, state}
    end
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, _state) do
    Logger.info("WebSocket client disconnected: #{inspect(reason)}")
    :ok
  end

  # Private helpers

  defp schedule_stats do
    Process.send_after(self(), :send_stats, @stats_interval)
  end

  defp build_stats do
    db_stats = Admin.stats()
    cluster_status = Cluster.status()
    swarm_status = Swarm.status()

    %{
      timestamp: DateTime.utc_now(),
      users: db_stats.users,
      torrents: db_stats.torrents,
      peers: db_stats.peers,
      active_swarms: db_stats.active_swarms,
      total_uploaded: db_stats.total_uploaded,
      total_downloaded: db_stats.total_downloaded,
      cluster: cluster_status,
      swarm: swarm_status,
      websocket_clients: client_count()
    }
  end

  defp build_swarm_list do
    Swarm.list_workers()
    |> Enum.take(100)
    |> Enum.map(fn {info_hash, pid} ->
      stats =
        try do
          B1tpoti0n.Swarm.Worker.get_stats(pid)
        catch
          _, _ -> {0, 0, 0}
        end

      {seeders, completed, leechers} = stats

      %{
        info_hash: Base.encode16(info_hash, case: :lower),
        seeders: seeders,
        leechers: leechers,
        completed: completed
      }
    end)
  end

  defp parse_events(events) do
    events
    |> Enum.map(&safe_to_event/1)
    |> Enum.reject(&is_nil/1)
  end

  defp safe_to_event(s) when is_binary(s) do
    atom = String.to_existing_atom(s)
    if atom in @valid_events, do: atom, else: nil
  rescue
    ArgumentError -> nil
  end

  defp safe_to_event(a) when is_atom(a) and a in @valid_events, do: a
  defp safe_to_event(_), do: nil

  defp to_atom(s) when is_binary(s) do
    atom = String.to_existing_atom(s)
    if atom in @valid_events, do: atom, else: nil
  rescue
    ArgumentError -> nil
  end

  defp to_atom(a) when is_atom(a) and a in @valid_events, do: a
  defp to_atom(_), do: nil
end
