defmodule TaurosWeb.WalletAccountLive.Index do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Wallet accounts
        <:subtitle>
          Receiving destinations registered by your agents. Tauros stores public addresses only.
        </:subtitle>
      </.header>

      <.table
        id="wallet_accounts"
        rows={@streams.wallet_accounts}
        row_click={
          fn {_id, wallet_account} -> JS.navigate(~p"/wallet-accounts/#{wallet_account}") end
        }
      >
        <:col :let={{_id, wallet_account}} label="Wallet name">{wallet_account.wallet_name}</:col>

        <:col :let={{_id, wallet_account}} label="Currency">{wallet_account.currency}</:col>

        <:col :let={{_id, wallet_account}} label="Public address">
          <span class="break-all font-mono text-xs">{wallet_account.public_address}</span>
        </:col>

        <:col :let={{_id, wallet_account}} label="Agent">{wallet_account.agent.name}</:col>

        <:action :let={{_id, wallet_account}}>
          <div class="sr-only">
            <.link navigate={~p"/wallet-accounts/#{wallet_account}"}>Show</.link>
          </div>
        </:action>
      </.table>

      <p :if={@empty?} id="empty-state" class="py-8 text-center opacity-70">
        No wallet accounts registered yet.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    wallet_accounts =
      Tauros.Revenue.list_wallet_accounts!(actor: socket.assigns[:current_user], load: :agent)

    {:ok,
     socket
     |> assign(:page_title, "Wallet accounts")
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:empty?, wallet_accounts == [])
     |> stream(:wallet_accounts, wallet_accounts)}
  end
end
