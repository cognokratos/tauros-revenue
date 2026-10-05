defmodule TaurosWeb.PaymentDestinationLive.Show do
  use TaurosWeb, :live_view

  alias Tauros.Revenue
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
        <:item title="State">
          <.state_badge id="destination-state" state={@destination.state} />
        </:item>

        <:item title="Label">{@destination.label}</:item>

        <:item title="Currency">{@destination.currency}</:item>

        <:item title="Network">
          {Network.label(@destination.network)} ({Network.rail(@destination.network)} rail)
        </:item>

        <:item title="Address"><span class="font-mono">{@destination.address}</span></:item>

        <:item title="Agent">{@destination.agent.name}</:item>

        <:item :if={@destination.supersedes} title="Replaces">
          <.link navigate={~p"/destinations/#{@destination.supersedes}"} class="link">
            {@destination.supersedes.label}
          </.link>
        </:item>

        <:item :if={@destination.superseded_by} title="Replaced by">
          <.link
            id="superseded-by"
            navigate={~p"/destinations/#{@destination.superseded_by}"}
            class="link"
          >
            {@destination.superseded_by.label}
          </.link>
        </:item>

        <:item title="Registered at">{@destination.inserted_at}</:item>
      </.list>

      <div
        :if={@can_deactivate?}
        id="deactivate-panel"
        class="flex flex-col gap-3 rounded-box border border-base-300 p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <p class="text-sm">
          Deactivating stops new invoices from using this destination, and blocks approval of
          pending ones that do. It cannot be undone; the record stays for history.
        </p>
        <.button
          id="deactivate-destination"
          phx-click="deactivate"
          data-confirm="Deactivate this destination? This cannot be undone."
          class="btn btn-outline btn-error"
        >
          Deactivate
        </.button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, socket |> assign(:page_title, "Payment destination") |> load(id)}
  end

  @impl true
  def handle_event("deactivate", _params, socket) do
    actor = socket.assigns.current_user

    case Revenue.deactivate_payment_destination(socket.assigns.destination, actor: actor) do
      {:ok, destination} ->
        {:noreply, socket |> put_flash(:info, "Destination deactivated") |> load(destination.id)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "The destination could not be deactivated")}
    end
  end

  defp load(socket, id) do
    actor = socket.assigns.current_user

    destination =
      Revenue.get_payment_destination!(id,
        actor: actor,
        load: [:agent, :supersedes, :superseded_by]
      )

    socket
    |> assign(:destination, destination)
    |> assign(
      :can_deactivate?,
      destination.state == :active and
        Revenue.can_deactivate_payment_destination?(actor, destination)
    )
  end
end
