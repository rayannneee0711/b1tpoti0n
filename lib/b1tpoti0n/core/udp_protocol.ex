defmodule B1tpoti0n.Core.UdpProtocol do
  @moduledoc """
  UDP tracker protocol encoder/decoder (BEP 15).

  ## Protocol Overview

  1. Connect: Client sends protocol_id + transaction_id, receives connection_id
  2. Announce: Client sends connection_id + announce data, receives peers
  3. Scrape: Client sends connection_id + info_hashes, receives stats

  ## Packet Formats

  Connect Request:  protocol_id(8) + action(4) + transaction_id(4) = 16 bytes
  Connect Response: action(4) + transaction_id(4) + connection_id(8) = 16 bytes

  Announce Request: connection_id(8) + action(4) + transaction_id(4) +
                    info_hash(20) + peer_id(20) + downloaded(8) + left(8) +
                    uploaded(8) + event(4) + ip(4) + key(4) + num_want(4) + port(2) = 98 bytes

  Announce Response: action(4) + transaction_id(4) + interval(4) + leechers(4) +
                     seeders(4) + peers(6*n) = 20+ bytes

  Scrape Request: connection_id(8) + action(4) + transaction_id(4) + info_hashes(20*n)
  Scrape Response: action(4) + transaction_id(4) + stats(12*n)
  """
  import Bitwise

  # Protocol constants
  @protocol_id 0x41727101980
  @action_connect 0
  @action_announce 1
  @action_scrape 2
  @action_error 3

  # Event constants
  @event_none 0
  @event_completed 1
  @event_started 2
  @event_stopped 3

  @type action :: :connect | :announce | :scrape | :error
  @type event :: :none | :completed | :started | :stopped

  @type connect_request :: %{
          transaction_id: non_neg_integer()
        }

  @type announce_request :: %{
          connection_id: non_neg_integer(),
          transaction_id: non_neg_integer(),
          info_hash: binary(),
          peer_id: binary(),
          downloaded: non_neg_integer(),
          left: non_neg_integer(),
          uploaded: non_neg_integer(),
          event: event(),
          ip: non_neg_integer(),
          key: non_neg_integer(),
          num_want: integer(),
          port: non_neg_integer()
        }

  @type scrape_request :: %{
          connection_id: non_neg_integer(),
          transaction_id: non_neg_integer(),
          info_hashes: [binary()]
        }

  # ============================================================================
  # Request Parsing
  # ============================================================================

  @doc """
  Parse a UDP request packet.
  Returns {:ok, action, request} or {:error, reason}.
  """
  @spec parse_request(binary()) :: {:ok, action(), map()} | {:error, String.t()}
  def parse_request(<<@protocol_id::64, @action_connect::32, transaction_id::32>>) do
    {:ok, :connect, %{transaction_id: transaction_id}}
  end

  def parse_request(
        <<connection_id::64, @action_announce::32, transaction_id::32, info_hash::binary-20,
          peer_id::binary-20, downloaded::64, left::64, uploaded::64, event::32, ip::32, key::32,
          num_want::signed-32, port::16, _rest::binary>>
      ) do
    {:ok, :announce,
     %{
       connection_id: connection_id,
       transaction_id: transaction_id,
       info_hash: info_hash,
       peer_id: peer_id,
       downloaded: downloaded,
       left: left,
       uploaded: uploaded,
       event: decode_event(event),
       ip: ip,
       key: key,
       num_want: if(num_want < 0, do: 50, else: num_want),
       port: port
     }}
  end

  def parse_request(<<connection_id::64, @action_scrape::32, transaction_id::32, rest::binary>>)
      when byte_size(rest) >= 20 and rem(byte_size(rest), 20) == 0 do
    info_hashes = for <<hash::binary-20 <- rest>>, do: hash

    {:ok, :scrape,
     %{
       connection_id: connection_id,
       transaction_id: transaction_id,
       info_hashes: info_hashes
     }}
  end

  def parse_request(<<_::64, action::32, _::binary>>) when action > 3 do
    {:error, "Unknown action: #{action}"}
  end

  def parse_request(data) when byte_size(data) < 16 do
    {:error, "Packet too short"}
  end

  def parse_request(_) do
    {:error, "Invalid packet format"}
  end

  # ============================================================================
  # Response Encoding
  # ============================================================================

  @doc """
  Encode a connect response.
  """
  @spec encode_connect_response(non_neg_integer(), non_neg_integer()) :: binary()
  def encode_connect_response(transaction_id, connection_id) do
    <<@action_connect::32, transaction_id::32, connection_id::64>>
  end

  @doc """
  Encode an announce response.
  peers should be a list of {ip_tuple, port} tuples.
  """
  @spec encode_announce_response(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          list()
        ) :: binary()
  def encode_announce_response(transaction_id, interval, leechers, seeders, peers) do
    peers_binary = encode_peers(peers)

    <<@action_announce::32, transaction_id::32, interval::32, leechers::32, seeders::32,
      peers_binary::binary>>
  end

  @doc """
  Encode a scrape response.
  stats should be a list of {seeders, completed, leechers} tuples.
  """
  @spec encode_scrape_response(non_neg_integer(), list()) :: binary()
  def encode_scrape_response(transaction_id, stats) do
    stats_binary =
      for {seeders, completed, leechers} <- stats, into: <<>> do
        <<seeders::32, completed::32, leechers::32>>
      end

    <<@action_scrape::32, transaction_id::32, stats_binary::binary>>
  end

  @doc """
  Encode an error response.
  """
  @spec encode_error_response(non_neg_integer(), String.t()) :: binary()
  def encode_error_response(transaction_id, message) do
    <<@action_error::32, transaction_id::32, message::binary>>
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp decode_event(@event_none), do: :none
  defp decode_event(@event_completed), do: :completed
  defp decode_event(@event_started), do: :started
  defp decode_event(@event_stopped), do: :stopped
  defp decode_event(_), do: :none

  @doc """
  Convert event atom to string for HTTP handler compatibility.
  """
  @spec event_to_string(event()) :: String.t() | nil
  def event_to_string(:none), do: nil
  def event_to_string(:completed), do: "completed"
  def event_to_string(:started), do: "started"
  def event_to_string(:stopped), do: "stopped"

  defp encode_peers(peers) do
    for {ip, port} <- peers, into: <<>> do
      encode_peer(ip, port)
    end
  end

  defp encode_peer({a, b, c, d}, port) when port >= 0 and port <= 65535 do
    <<a::8, b::8, c::8, d::8, port::16>>
  end

  defp encode_peer(_, _), do: <<>>

  @doc """
  Generate a random connection_id.
  Uses crypto random for security.
  """
  @spec generate_connection_id() :: non_neg_integer()
  def generate_connection_id do
    <<id::64>> = :crypto.strong_rand_bytes(8)
    id
  end

  @doc """
  Convert a 32-bit IP integer to a tuple.
  """
  @spec int_to_ip(non_neg_integer()) :: {byte(), byte(), byte(), byte()}
  def int_to_ip(ip_int) do
    {bsr(ip_int, 24) &&& 0xFF, bsr(ip_int, 16) &&& 0xFF, bsr(ip_int, 8) &&& 0xFF, ip_int &&& 0xFF}
  end

  @doc """
  Validate that a connection_id was issued by us and hasn't expired.
  This should be called against a cache of issued connection_ids.
  """
  @spec valid_connection_id?(non_neg_integer(), map()) :: boolean()
  def valid_connection_id?(connection_id, cache) do
    case Map.get(cache, connection_id) do
      nil -> false
      expires_at -> DateTime.compare(expires_at, DateTime.utc_now()) == :gt
    end
  end
end
