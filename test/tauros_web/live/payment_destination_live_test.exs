defmodule TaurosWeb.PaymentDestinationLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "lists the destinations of the human's agents", %{conn: conn, user: user} do
    agent = agent(user, name: "Treasury Agent")

    destination =
      payment_destination(agent, %{
        label: "Cold storage",
        currency: :BTC,
        network: :bitcoin,
        address: "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr"
      })

    foreign = payment_destination(agent(user()))

    {:ok, view, _html} = live(conn, ~p"/destinations")

    for text <- ["Cold storage", "BTC", "Bitcoin mainnet", "Treasury Agent"] do
      assert has_element?(view, "#payment_destinations-#{destination.id}", text)
    end

    refute has_element?(view, "#payment_destinations-#{foreign.id}")
    refute has_element?(view, "#empty-state")
  end

  test "shows an empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/destinations")
    assert has_element?(view, "#empty-state", "No payment destinations registered yet")
  end

  test "humans cannot register destinations from the UI", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/destinations")
    refute has_element?(view, "a[href='/destinations/new']")
  end

  test "Show displays a destination with its network and rail", %{conn: conn, user: user} do
    destination =
      payment_destination(agent(user), %{label: "Ops", currency: :USDC, network: :arbitrum})

    {:ok, _view, html} = live(conn, ~p"/destinations/#{destination}")
    assert html =~ "Ops"
    assert html =~ "Arbitrum One"
    assert html =~ destination.address
  end

  test "requires authentication" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/destinations")
  end
end
