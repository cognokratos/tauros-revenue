defmodule TaurosWeb.AccountLiveTest do
  use TaurosWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tauros.WalletsFixtures
  import Tauros.AgentsFixtures
  import Tauros.AccountsFixtures

  setup :register_and_log_in_user

  describe "Accounts Index" do
    test "lists all accounts for admin's agents", %{conn: conn, user: user} do
      agent = agent_fixture(%{user_id: user.id})
      account1 = account_fixture(agent)
      account2 = account_fixture(agent)

      {:ok, view, _html} = live(conn, ~p"/accounts")

      assert has_element?(view, "#accounts")

      # Check both accounts are listed by their IDs
      assert has_element?(view, "#accounts-#{account1.id}")
      assert has_element?(view, "#accounts-#{account2.id}")
    end

    test "displays empty state when no accounts exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")

      assert has_element?(view, "#empty-state")
      assert has_element?(view, "#empty-state", "No accounts registered yet")
    end

    test "displays account details correctly", %{conn: conn, user: user} do
      agent = agent_fixture(%{user_id: user.id})

      account =
        account_fixture(agent, %{
          "wallet_name" => "My Bitcoin Wallet",
          "currency" => "BTC",
          "public_address" => "bc1pxy2kgdygjrsqtzq2n0yrf2493p3xcn65v4ezuqpf9eajsuu4k4uqjc37h0"
        })

      {:ok, view, _html} = live(conn, ~p"/accounts")

      assert has_element?(view, "#accounts-#{account.id}", "My Bitcoin Wallet")
      assert has_element?(view, "#accounts-#{account.id}", "BTC")
      assert has_element?(view, "#accounts-#{account.id}", agent.name)
    end

    test "does not display accounts from other admins' agents", %{conn: conn, user: user1} do
      user2 = user_fixture()

      agent1 = agent_fixture(%{user_id: user1.id})
      agent2 = agent_fixture(%{user_id: user2.id})

      account1 = account_fixture(agent1)
      account2 = account_fixture(agent2)

      {:ok, view, _html} = live(conn, ~p"/accounts")

      # Should only see account from user1's agent
      assert has_element?(view, "#accounts-#{account1.id}")
      refute has_element?(view, "#accounts-#{account2.id}")
    end

    test "requires authentication", %{conn: conn} do
      # Use an unauthenticated connection
      unauth_conn = %{conn | private: Map.delete(conn.private, :plug_session)}
      {:error, {:redirect, %{to: path}}} = live(unauth_conn, ~p"/accounts")
      assert path == ~p"/users/log-in"
    end
  end
end
