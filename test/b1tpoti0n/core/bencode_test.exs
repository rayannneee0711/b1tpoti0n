defmodule B1tpoti0n.Core.BencodeTest do
  @moduledoc """
  Tests for Bencode encoding of tracker responses.
  """
  use ExUnit.Case, async: true

  alias B1tpoti0n.Core.Bencode

  describe "encode/1" do
    test "encodes strings" do
      assert Bencode.encode("spam") == "4:spam"
      assert Bencode.encode("") == "0:"
      assert Bencode.encode("hello world") == "11:hello world"
    end

    test "encodes integers" do
      assert Bencode.encode(0) == "i0e"
      assert Bencode.encode(42) == "i42e"
      assert Bencode.encode(-42) == "i-42e"
    end

    test "encodes lists" do
      assert Bencode.encode(["spam", "eggs"]) == "l4:spam4:eggse"
      assert Bencode.encode([]) == "le"
    end

    test "encodes maps with sorted keys" do
      assert Bencode.encode(%{"cow" => "moo", "spam" => "eggs"}) == "d3:cow3:moo4:spam4:eggse"
    end

    test "encodes atoms as strings" do
      assert Bencode.encode(:hello) == "5:hello"
    end
  end

  describe "encode_announce_response/5 with IPv4 peers" do
    test "encodes compact IPv4 peers correctly" do
      peers = [
        %{ip: {192, 168, 1, 1}, port: 6881},
        %{ip: {10, 0, 0, 1}, port: 6882}
      ]

      response = Bencode.encode_announce_response(1800, 5, 10, peers, true)

      # The response should contain a 12-byte peers string (2 peers * 6 bytes each)
      assert response =~ "5:peers12:"
      assert response =~ "8:completei5e"
      assert response =~ "10:incompletei10e"
      assert response =~ "8:intervali1800e"
    end

    test "encodes dictionary format peers" do
      peers = [
        %{ip: {192, 168, 1, 1}, port: 6881}
      ]

      response = Bencode.encode_announce_response(1800, 5, 10, peers, false)

      assert response =~ "5:peersl"
      assert response =~ "2:ip11:192.168.1.1"
      assert response =~ "4:porti6881e"
    end
  end

  describe "encode_announce_response/5 with IPv6 peers (BEP 7)" do
    test "separates IPv4 and IPv6 peers in compact mode" do
      peers = [
        %{ip: {192, 168, 1, 1}, port: 6881},
        %{ip: {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1}, port: 6882}
      ]

      response = Bencode.encode_announce_response(1800, 5, 10, peers, true)

      # Should contain 'peers' key with 6 bytes (1 IPv4 peer)
      assert response =~ "5:peers6:"
      # Should contain 'peers6' key with 18 bytes (1 IPv6 peer)
      assert response =~ "6:peers618:"
    end

    test "omits peers6 key when no IPv6 peers" do
      peers = [
        %{ip: {192, 168, 1, 1}, port: 6881}
      ]

      response = Bencode.encode_announce_response(1800, 5, 10, peers, true)

      # Should not contain "6:peers6" which is the bencoded key for peers6
      # (Note: "5:peers6:" contains "peers6" but that's the peers key with 6-byte value)
      refute response =~ "6:peers6"
    end

    test "encodes IPv6 in compact format correctly (18 bytes per peer)" do
      # 2001:db8::1
      peers = [
        %{ip: {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1}, port: 6881}
      ]

      response = Bencode.encode_announce_response(1800, 0, 0, peers, true)

      # Extract the peers6 binary
      # Response format: d...6:peers618:<18 bytes>...e
      assert response =~ "6:peers618:"

      # The 18 bytes should be: 2001:0db8:0000:0000:0000:0000:0000:0001 + port
      expected_ip = <<0x2001::16, 0x0DB8::16, 0::16, 0::16, 0::16, 0::16, 0::16, 1::16, 6881::16>>
      assert String.contains?(response, expected_ip)
    end

    test "encodes IPv6 in dictionary format" do
      peers = [
        %{ip: {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1}, port: 6881}
      ]

      response = Bencode.encode_announce_response(1800, 0, 0, peers, false)

      # Dictionary format should include the IPv6 address
      assert response =~ "5:peersl"
      assert response =~ "4:porti6881e"
    end

    test "handles string IP addresses" do
      peers = [
        %{ip: "192.168.1.1", port: 6881},
        %{ip: "2001:db8::1", port: 6882}
      ]

      response = Bencode.encode_announce_response(1800, 0, 0, peers, true)

      # Should handle both string formats
      assert response =~ "5:peers6:"
      assert response =~ "6:peers618:"
    end
  end

  describe "encode_scrape_response/1" do
    test "encodes scrape response correctly" do
      info_hash = :crypto.strong_rand_bytes(20)
      torrents = [{info_hash, 100, 50, 25}]

      response = Bencode.encode_scrape_response(torrents)

      assert response =~ "5:files"
      assert response =~ "8:completei100e"
      assert response =~ "10:downloadedi50e"
      assert response =~ "10:incompletei25e"
    end
  end

  describe "encode_error/1" do
    test "encodes error response correctly" do
      response = Bencode.encode_error("Torrent not registered")

      assert response == "d14:failure reason22:Torrent not registerede"
    end
  end

  describe "apply_jitter/2" do
    test "returns original interval when jitter is 0" do
      assert Bencode.apply_jitter(1800, 0) == 1800
      assert Bencode.apply_jitter(1800, 0.0) == 1800
    end

    test "applies jitter within expected range" do
      base_interval = 1800
      jitter = 0.1

      # Run multiple times to test randomness
      results =
        for _ <- 1..100 do
          Bencode.apply_jitter(base_interval, jitter)
        end

      # All results should be within ±10% of base
      min_expected = trunc(base_interval * 0.9)
      max_expected = trunc(base_interval * 1.1)

      assert Enum.all?(results, fn r -> r >= min_expected and r <= max_expected end)

      # Should have some variation (not all same value)
      assert length(Enum.uniq(results)) > 1
    end

    test "never returns less than 1" do
      # Even with 100% jitter on interval of 1
      results =
        for _ <- 1..100 do
          Bencode.apply_jitter(1, 1.0)
        end

      assert Enum.all?(results, fn r -> r >= 1 end)
    end
  end
end
