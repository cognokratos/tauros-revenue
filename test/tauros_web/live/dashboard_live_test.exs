defmodule TaurosWeb.DashboardLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "counts only what the signed-in human owns", %{conn: conn, user: user} do
    agent = agent(user)
    customer(agent)
    customer(agent)
    payment_destination(agent)
    agent(user()) |> customer()

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#agents-metric", "1")
    assert has_element?(view, "#customers-metric", "2")
    assert has_element?(view, "#destinations-metric", "1")
    assert has_element?(view, "#agents-metric[href='/agents']")
  end

  test "offers every section in the mobile menu, including sign-out", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    for path <- ["/", "/invoices/review", "/invoices", "/agents", "/customers", "/destinations"] do
      assert has_element?(view, "#mobile-menu a[href='#{path}']")
    end

    assert has_element?(view, "#mobile-menu a[href='/sign-out'][data-method='delete']")
    assert has_element?(view, "#mobile-menu-button[aria-controls='mobile-menu']")
  end

  test "redirects anonymous visitors to sign in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/")
  end
end
