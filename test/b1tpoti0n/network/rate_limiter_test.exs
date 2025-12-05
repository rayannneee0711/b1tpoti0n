defmodule B1tpoti0n.Network.RateLimiterTest do
  @moduledoc """
  Tests for IP-based rate limiting.
  """
  use ExUnit.Case, async: false

  alias B1tpoti0n.Network.RateLimiter

  setup do
    # Reset rate limiter state between tests
    RateLimiter.reset("test_ip")
    RateLimiter.reset("192.168.1.1")
    :ok
  end

  describe "check/2" do
    test "allows requests under the limit" do
      # Default limit is 30 announces per minute
      for _ <- 1..10 do
        assert :ok = RateLimiter.check("test_ip", :announce)
      end
    end

    test "blocks requests over the limit" do
      # Hit the limit (default: 30)
      for _ <- 1..30 do
        RateLimiter.check("192.168.1.1", :announce)
      end

      # Next request should be rate limited
      assert {:error, :rate_limited, retry_after} = RateLimiter.check("192.168.1.1", :announce)
      assert is_integer(retry_after)
      assert retry_after >= 0
    end

    test "different IPs have separate limits" do
      # Use up limit for IP 1
      for _ <- 1..30 do
        RateLimiter.check("10.0.0.1", :announce)
      end

      # IP 2 should still be allowed
      assert :ok = RateLimiter.check("10.0.0.2", :announce)
    end

    test "different limit types have separate limits" do
      # Use up announce limit
      for _ <- 1..30 do
        RateLimiter.check("test_ip", :announce)
      end

      # Scrape should still be allowed
      assert :ok = RateLimiter.check("test_ip", :scrape)
    end
  end

  describe "reset/1" do
    test "resets all limits for an IP" do
      # Use up the limit
      for _ <- 1..30 do
        RateLimiter.check("test_ip", :announce)
      end

      assert {:error, :rate_limited, _} = RateLimiter.check("test_ip", :announce)

      # Reset
      RateLimiter.reset("test_ip")

      # Should be allowed again
      assert :ok = RateLimiter.check("test_ip", :announce)
    end
  end

  describe "reset/2" do
    test "resets specific limit type for an IP" do
      # Use up both limits
      for _ <- 1..30 do
        RateLimiter.check("test_ip", :announce)
      end

      for _ <- 1..10 do
        RateLimiter.check("test_ip", :scrape)
      end

      # Reset only announce
      RateLimiter.reset("test_ip", :announce)

      # Announce should be allowed, scrape still blocked
      assert :ok = RateLimiter.check("test_ip", :announce)
      assert {:error, :rate_limited, _} = RateLimiter.check("test_ip", :scrape)
    end
  end

  describe "get_state/1" do
    test "returns current rate limit state" do
      # Make some requests
      for _ <- 1..5 do
        RateLimiter.check("test_ip", :announce)
      end

      state = RateLimiter.get_state("test_ip")

      assert is_map(state)
      assert Map.has_key?(state, :announce)
      assert state.announce.count == 5
      assert state.announce.remaining == 25  # 30 - 5
    end
  end

  describe "stats/0" do
    test "returns overall statistics" do
      stats = RateLimiter.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :entries)
      assert Map.has_key?(stats, :memory_bytes)
    end
  end

  describe "whitelist" do
    test "whitelisted IPs are not rate limited" do
      # 127.0.0.1 is whitelisted by default
      for _ <- 1..100 do
        assert :ok = RateLimiter.check("127.0.0.1", :announce)
      end
    end
  end
end
