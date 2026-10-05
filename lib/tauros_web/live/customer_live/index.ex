defmodule TaurosWeb.CustomerLive.Index do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Customers
        <:actions>
          <.button variant="primary" navigate={~p"/customers/new"}>
            <.icon name="hero-plus" /> New Customer
          </.button>
        </:actions>
      </.header>

      <.table
        id="customers"
        rows={@streams.customers}
        row_click={fn {_id, customer} -> JS.navigate(~p"/customers/#{customer}") end}
      >
        <:col :let={{_id, customer}} label="Name">{customer.name}</:col>

        <:col :let={{_id, customer}} label="Email">{customer.email}</:col>

        <:col :let={{_id, customer}} label="Agent">{customer.agent.name}</:col>

        <:col :let={{_id, customer}} label="Created at">{customer.inserted_at}</:col>

        <:action :let={{_id, customer}}>
          <div class="sr-only">
            <.link navigate={~p"/customers/#{customer}"}>Show</.link>
          </div>

          <.link navigate={~p"/customers/#{customer}/edit"}>Edit</.link>
        </:action>

        <:action :let={{_id, customer}}>
          <.link
            phx-click={JS.push("delete", value: %{id: customer.id})}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <p :if={@empty?} id="empty-state" class="py-8 text-center opacity-70">
        No customers yet. Create one to get started.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Customers")
     |> assign_new(:current_user, fn -> nil end)
     |> stream_customers()}
  end

  defp stream_customers(socket) do
    customers =
      Tauros.Revenue.list_customers!(actor: socket.assigns.current_user, load: :agent)

    socket
    |> assign(:empty?, customers == [])
    |> stream(:customers, customers, reset: true)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    with {:ok, customer} <- Tauros.Revenue.get_customer(id, actor: actor),
         :ok <- Tauros.Revenue.destroy_customer(customer, actor: actor) do
      {:noreply, stream_customers(socket)}
    else
      _error ->
        {:noreply,
         socket |> put_flash(:error, "The customer could not be deleted") |> stream_customers()}
    end
  end
end
