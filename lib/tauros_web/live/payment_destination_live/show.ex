defmodule TaurosWeb.PaymentDestinationLive.Show do
  use TaurosWeb, :live_view

  alias Tauros.Revenue.Network

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@destination.label}
        <:subtitle>Payment destination {@destination.id}</:subtitle>

        <:actions>
          <.button navigate={~p"/destinations"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@destination.id}</:item>

        <:item title="Label">{@destination.label}</:item>

        <:item title="Currency">{@destination.currency}</:item>

        <:item title="Network">
          {Network.label(@destination.network)} ({Network.rail(@destination.network)} rail)
        </:item>

        <:item title="Address"><span class="font-mono">{@destination.address}</span></:item>

        <:item title="Agent">{@destination.agent.name}</:item>

        <:item title="Registered at">{@destination.inserted_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Payment destination")
     |> assign(
       :destination,
       Tauros.Revenue.get_payment_destination!(id,
         actor: socket.assigns.current_user,
         load: :agent
       )
     )}
  end
end
