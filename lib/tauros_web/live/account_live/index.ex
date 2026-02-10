defmodule TaurosWeb.AccountLive.Index do
  use TaurosWeb, :live_view

  alias Tauros.Wallets

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Accounts
      </.header>

      <div id="accounts" phx-update="stream" class="space-y-4">
        <div id="empty-state" class="hidden only:block">
          <div class="text-center py-12 text-gray-500">
            <p class="text-sm">No accounts registered yet.</p>
          </div>
        </div>
        <%= for {id, account} <- @streams.accounts do %>
          <.card id={id}>
            <div class="px-4 py-5 sm:px-6">
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="font-semibold text-lg">{account.wallet_name}</h3>
                  <p class="text-gray-600 text-sm mt-1">
                    Currency: <span class="font-mono">{account.currency}</span>
                  </p>
                  <p class="text-gray-600 text-sm mt-2">
                    Address: <span class="font-mono break-all text-xs">{account.public_address}</span>
                  </p>
                  <p class="text-gray-600 text-sm mt-2">
                    Agent: {account.agent.name}
                  </p>
                </div>
              </div>
            </div>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Wallets.subscribe_accounts(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Accounts")
     |> stream(:accounts, Wallets.list_accounts_for_scope(socket.assigns.current_scope))}
  end

  @impl true
  def handle_info({type, %Tauros.Wallets.Account{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :accounts,
       Wallets.list_accounts_for_scope(socket.assigns.current_scope),
       reset: true
     )}
  end
end
