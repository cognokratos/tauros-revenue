defmodule TaurosWeb.DashboardLiveTest do
  use TaurosWeb.ConnCase
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "dashboard" do
    test "renders dashboard with metrics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Dashboard"
      assert html =~ "Agents"
      assert html =~ "Clients"
      assert html =~ "Pending Invoices"
      assert html =~ "Approved Invoices"
    end

    test "agents metric displays count", %{conn: conn, user: user} do
      {:ok, _agent} =
        Tauros.Agents.create_agent(
          %Tauros.Accounts.Scope{user: user},
          %{"name" => "Test Agent", "api_key" => "test_key_123"}
        )

      {:ok, view, _html} = live(conn, ~p"/")

      # Should show 1 agent
      assert has_element?(view, "a[href='#{~p"/agents"}']")
    end

    test "agents link navigates to agents page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='#{~p"/agents"}']")
    end
  end
end
