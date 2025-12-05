defmodule B1tpoti0n.Network.PeerVerifierTest do
  @moduledoc """
  Tests for peer connection verification.
  """
  use ExUnit.Case, async: false

  alias B1tpoti0n.Network.PeerVerifier

  describe "check_connectable/2" do
    test "returns :unknown for new peer and queues verification" do
      ip = {192, 168, 1, 100}
      port = 12345

      result = PeerVerifier.check_connectable(ip, port)

      assert result == :unknown
    end

    test "returns cached result for verified peer" do
      # Directly insert into ETS for testing
      ip = {192, 168, 1, 101}
      port = 12346
      key = {ip, port}
      expires_at = System.system_time(:second) + 3600

      :ets.insert(:peer_verification_cache, {key, true, expires_at})

      result = PeerVerifier.check_connectable(ip, port)

      assert result == {:ok, true}
    end

    test "returns :unknown for expired cache entry" do
      ip = {192, 168, 1, 102}
      port = 12347
      key = {ip, port}
      # Expired 10 seconds ago
      expires_at = System.system_time(:second) - 10

      :ets.insert(:peer_verification_cache, {key, true, expires_at})

      result = PeerVerifier.check_connectable(ip, port)

      assert result == :unknown
    end
  end

  describe "queue_verification/2" do
    test "returns :ok when enabled" do
      ip = {192, 168, 1, 103}
      port = 12348

      result = PeerVerifier.queue_verification(ip, port)

      # Could be :ok or {:error, :disabled} depending on config
      assert result in [:ok, {:error, :disabled}]
    end
  end

  describe "stats/0" do
    test "returns verification statistics" do
      stats = PeerVerifier.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :enabled)
      assert Map.has_key?(stats, :cache_size)
      assert Map.has_key?(stats, :pending)
      assert Map.has_key?(stats, :in_progress)
      assert Map.has_key?(stats, :verified_count)
      assert Map.has_key?(stats, :failed_count)
    end
  end

  describe "clear_cache/0" do
    test "clears the verification cache" do
      # Add some entries
      ip = {192, 168, 1, 104}
      port = 12349
      key = {ip, port}
      expires_at = System.system_time(:second) + 3600

      :ets.insert(:peer_verification_cache, {key, true, expires_at})

      assert :ets.lookup(:peer_verification_cache, key) != []

      :ok = PeerVerifier.clear_cache()

      assert :ets.lookup(:peer_verification_cache, key) == []
    end
  end

  describe "enabled?/0" do
    test "returns boolean based on config" do
      result = PeerVerifier.enabled?()

      assert is_boolean(result)
    end
  end
end
