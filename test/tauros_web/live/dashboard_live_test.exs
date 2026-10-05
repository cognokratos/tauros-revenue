defmodule TaurosWeb.DashboardLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "counts only what the signed-in human owns", %{conn: conn, user: user} do
    agent = agent(user)
    customer(agent)
    customer(agent)
    wallet_account(agent)
    agent(user()) |> customer()

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#agents-metric", "1")
    assert has_element?(view, "#customers-metric", "2")
    assert has_element?(view, "#wallet-accounts-metric", "1")
    assert has_element?(view, "#agents-metric[href='/agents']")
  end

  test "redirects anonymous visitors to sign in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/")
  end
end
