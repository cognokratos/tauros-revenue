defmodule TaurosWeb.PaymentDestinationLive.Index do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        Payment destinations
        <:subtitle>
          Payment destinations tell agents where an invoice can be paid: a currency, the network it
          arrives on and a public address. Tauros stores public receiving information only.
        </:subtitle>
      </.header>

      <.table
        id="payment_destinations"
        rows={@streams.payment_destinations}
        row_click={fn {_id, destination} -> JS.navigate(~p"/destinations/#{destination}") end}
      >
        <:col :let={{_id, destination}} label="Label">{destination.label}</:col>

        <:col :let={{_id, destination}} label="State">
          <.state_badge state={destination.state} />
        </:col>

        <:col :let={{_id, destination}} label="Currency">{destination.currency}</:col>

        <:col :let={{_id, destination}} label="Network">
          {Tauros.Revenue.Network.label(destination.network)}
        </:col>

        <:col :let={{_id, destination}} label="Address" class="hidden sm:table-cell">
          <span class="break-all font-mono text-xs">{destination.address}</span>
        </:col>

        <:col :let={{_id, destination}} label="Agent" class="hidden sm:table-cell">
          {destination.agent.name}
        </:col>

        <:action :let={{_id, destination}}>
          <div class="sr-only">
            <.link navigate={~p"/destinations/#{destination}"}>Show</.link>
          </div>
        </:action>
      </.table>

      <p :if={@empty?} id="empty-state" class="py-8 text-center opacity-70">
        No payment destinations registered yet.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    destinations =
      Tauros.Revenue.list_payment_destinations!(
        actor: socket.assigns[:current_user],
        load: :agent
      )

    {:ok,
     socket
     |> assign(:page_title, "Payment destinations")
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:empty?, destinations == [])
     |> stream(:payment_destinations, destinations)}
  end
end
