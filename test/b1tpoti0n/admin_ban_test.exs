defmodule B1tpoti0n.AdminBanTest do
  @moduledoc """
  Tests for IP banning functionality.
  """
  use B1tpoti0n.DataCase, async: false

  alias B1tpoti0n.Admin
  alias B1tpoti0n.Store.Manager
  alias B1tpoti0n.Persistence.Schemas.BannedIp

  setup do
    # Clean up any existing bans
    Repo.delete_all(BannedIp)
    Manager.reload_banned_ips()
    :ok
  end

  describe "ban_ip/3" do
    test "bans an IP address" do
      assert {:ok, ban} = Admin.ban_ip("192.168.1.100", "Test ban")

      assert ban.ip == "192.168.1.100"
      assert ban.reason == "Test ban"
      assert is_nil(ban.expires_at)
    end

    test "bans a CIDR range" do
      assert {:ok, ban} = Admin.ban_ip("10.0.0.0/8", "Internal network")

      assert ban.ip == "10.0.0.0/8"
    end

    test "bans with expiration" do
      assert {:ok, ban} = Admin.ban_ip("192.168.1.100", "Temp ban", duration: 3600)

      assert ban.expires_at != nil
      # Expires in about an hour
      diff = DateTime.diff(ban.expires_at, DateTime.utc_now(), :second)
      assert diff >= 3590 and diff <= 3610
    end

    test "returns error for invalid IP" do
      assert {:error, changeset} = Admin.ban_ip("not-an-ip", "Invalid")
      assert "invalid IP address" in errors_on(changeset).ip
    end

    test "returns error for duplicate ban" do
      {:ok, _} = Admin.ban_ip("192.168.1.100", "First ban")
      assert {:error, _changeset} = Admin.ban_ip("192.168.1.100", "Duplicate")
    end
  end

  describe "unban_ip/1" do
    test "removes a ban" do
      {:ok, _} = Admin.ban_ip("192.168.1.100", "Test ban")
      assert {:ok, _} = Admin.unban_ip("192.168.1.100")
      assert Admin.get_ban("192.168.1.100") == nil
    end

    test "returns error for non-existent ban" do
      assert {:error, :not_found} = Admin.unban_ip("10.10.10.10")
    end
  end

  describe "list_bans/0" do
    test "returns all bans" do
      {:ok, _} = Admin.ban_ip("192.168.1.1", "Ban 1")
      {:ok, _} = Admin.ban_ip("192.168.1.2", "Ban 2")

      bans = Admin.list_bans()
      assert length(bans) == 2
    end
  end

  describe "list_active_bans/0" do
    test "excludes expired bans" do
      # Create an expired ban (manually set expires_at in the past)
      {:ok, _} = Admin.ban_ip("192.168.1.1", "Expired", duration: -3600)
      {:ok, _} = Admin.ban_ip("192.168.1.2", "Active")

      active = Admin.list_active_bans()
      assert length(active) == 1
      assert hd(active).ip == "192.168.1.2"
    end
  end

  describe "Manager.check_banned/1" do
    test "returns :ok for non-banned IP" do
      assert :ok = Manager.check_banned("192.168.1.100")
    end

    test "returns {:banned, reason} for banned IP" do
      {:ok, _} = Admin.ban_ip("192.168.1.100", "Test reason")

      assert {:banned, "Test reason"} = Manager.check_banned("192.168.1.100")
    end

    test "matches CIDR ranges" do
      {:ok, _} = Admin.ban_ip("192.168.0.0/16", "Entire subnet")

      assert {:banned, "Entire subnet"} = Manager.check_banned("192.168.1.100")
      assert {:banned, "Entire subnet"} = Manager.check_banned("192.168.255.255")
      assert :ok = Manager.check_banned("192.169.0.1")
    end

    test "accepts IP tuple format" do
      {:ok, _} = Admin.ban_ip("192.168.1.100", "Test")

      assert {:banned, "Test"} = Manager.check_banned({192, 168, 1, 100})
    end

    test "ignores expired bans" do
      {:ok, _} = Admin.ban_ip("192.168.1.100", "Expired", duration: -1)

      assert :ok = Manager.check_banned("192.168.1.100")
    end
  end

  describe "cleanup_expired_bans/0" do
    test "removes expired bans" do
      {:ok, _} = Admin.ban_ip("192.168.1.1", "Expired", duration: -3600)
      {:ok, _} = Admin.ban_ip("192.168.1.2", "Active")

      assert length(Admin.list_bans()) == 2

      {count, _} = Admin.cleanup_expired_bans()
      assert count == 1

      bans = Admin.list_bans()
      assert length(bans) == 1
      assert hd(bans).ip == "192.168.1.2"
    end
  end

  # Helper to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
