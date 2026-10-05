defmodule TaurosWeb.WalletAccountLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "lists the wallet accounts of the human's agents", %{conn: conn, user: user} do
    agent = agent(user, name: "Treasury Agent")

    account =
      wallet_account(agent, %{
        wallet_name: "My Bitcoin Wallet",
        currency: :BTC,
        public_address: "bc1pxy2kgdygjrsqtzq2n0yrf2493p3xcn65v4ezuqpf9eajsuu4k4uqjc37h0"
      })

    foreign = wallet_account(agent(user()))

    {:ok, view, _html} = live(conn, ~p"/wallet-accounts")

    for text <- ["My Bitcoin Wallet", "BTC", "Treasury Agent"] do
      assert has_element?(view, "#wallet_accounts-#{account.id}", text)
    end

    refute has_element?(view, "#wallet_accounts-#{foreign.id}")
    refute has_element?(view, "#empty-state")
  end

  test "shows an empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wallet-accounts")
    assert has_element?(view, "#empty-state", "No wallet accounts registered yet")
  end

  test "humans cannot register wallet accounts from the UI", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wallet-accounts")
    refute has_element?(view, "a[href='/wallet-accounts/new']")
  end

  test "Show displays a wallet account", %{conn: conn, user: user} do
    account = wallet_account(agent(user), %{wallet_name: "Ops Wallet"})
    {:ok, _view, html} = live(conn, ~p"/wallet-accounts/#{account}")
    assert html =~ "Ops Wallet"
    assert html =~ account.public_address
  end

  test "requires authentication" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/wallet-accounts")
  end
end
