defmodule B1tpoti0n.Network.UdpServer do
  @moduledoc """
  UDP tracker server implementing BEP 15.

  Listens for UDP packets and dispatches to the handler.
  Manages connection_ids with automatic expiration.
  """
  use GenServer
  require Logger

  alias B1tpoti0n.Core.UdpProtocol
  alias B1tpoti0n.Network.UdpHandler

  @connection_timeout_seconds 120
  @cleanup_interval_ms :timer.minutes(1)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a connection_id is valid.
  """
  @spec valid_connection?(non_neg_integer()) :: boolean()
  def valid_connection?(connection_id) do
    GenServer.call(__MODULE__, {:valid_connection, connection_id})
  end

  @doc """
  Generate and register a new connection_id.
  """
  @spec new_connection() :: non_neg_integer()
  def new_connection do
    GenServer.call(__MODULE__, :new_connection)
  end

  @doc """
  Get server statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port) || Application.get_env(:b1tpoti0n, :udp_port, 8080)

    case :gen_udp.open(port, [:binary, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("UDP tracker listening on port #{port}")
        schedule_cleanup()

        {:ok,
         %{
           socket: socket,
           port: port,
           connections: %{},
           packets_received: 0,
           packets_sent: 0
         }}

      {:error, reason} ->
        Logger.error("Failed to open UDP socket on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:valid_connection, connection_id}, _from, state) do
    valid = UdpProtocol.valid_connection_id?(connection_id, state.connections)
    {:reply, valid, state}
  end

  @impl true
  def handle_call(:new_connection, _from, state) do
    connection_id = UdpProtocol.generate_connection_id()
    timeout = Application.get_env(:b1tpoti0n, :udp_connection_timeout, @connection_timeout_seconds)
    expires_at = DateTime.add(DateTime.utc_now(), timeout, :second)

    new_connections = Map.put(state.connections, connection_id, expires_at)

    {:reply, connection_id, %{state | connections: new_connections}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      port: state.port,
      active_connections: map_size(state.connections),
      packets_received: state.packets_received,
      packets_sent: state.packets_sent
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:udp, socket, ip, port, data}, state) do
    # Process packet asynchronously
    Task.start(fn ->
      response = UdpHandler.handle_packet(data, ip)

      if response do
        :gen_udp.send(socket, ip, port, response)
      end
    end)

    {:noreply, %{state | packets_received: state.packets_received + 1}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()

    new_connections =
      state.connections
      |> Enum.reject(fn {_id, expires_at} ->
        DateTime.compare(expires_at, now) != :gt
      end)
      |> Map.new()

    expired_count = map_size(state.connections) - map_size(new_connections)

    if expired_count > 0 do
      Logger.debug("Cleaned up #{expired_count} expired UDP connections")
    end

    schedule_cleanup()
    {:noreply, %{state | connections: new_connections}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.socket do
      :gen_udp.close(state.socket)
    end

    :ok
  end

  # Private

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
