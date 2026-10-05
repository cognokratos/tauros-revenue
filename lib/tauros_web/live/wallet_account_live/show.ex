defmodule TaurosWeb.WalletAccountLive.Show do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@wallet_account.wallet_name}
        <:subtitle>Wallet account {@wallet_account.id}</:subtitle>

        <:actions>
          <.button navigate={~p"/wallet-accounts"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@wallet_account.id}</:item>

        <:item title="Wallet name">{@wallet_account.wallet_name}</:item>

        <:item title="Public address">{@wallet_account.public_address}</:item>

        <:item title="Currency">{@wallet_account.currency}</:item>

        <:item title="Agent">{@wallet_account.agent.name}</:item>

        <:item title="Registered at">{@wallet_account.inserted_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Wallet account")
     |> assign(
       :wallet_account,
       Ash.get!(Tauros.Revenue.WalletAccount, id,
         actor: socket.assigns.current_user,
         load: :agent
       )
     )}
  end
end
