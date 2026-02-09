defmodule TaurosWeb.CustomerLive.Index do
  use TaurosWeb, :live_view

  alias Tauros.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Customers
        <:actions>
          <.button variant="primary" navigate={~p"/customers/new"}>
            <.icon name="hero-plus" /> New Customer
          </.button>
        </:actions>
      </.header>

      <div id="customers" phx-update="stream" class="space-y-4">
        <div id="empty-state" style="display: none">
          <div class="text-center py-8 text-gray-500">
            No customers yet. Create one to get started.
          </div>
        </div>
        <%= for {id, customer} <- @streams.customers do %>
          <.card id={id}>
            <div class="px-4 py-5 sm:px-6">
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="font-semibold text-lg">{customer.name}</h3>
                  <p class="text-gray-600 text-sm">{customer.email}</p>
                  <p class="text-gray-500 text-sm mt-2">Agent: {customer.agent.name}</p>
                </div>
                <div class="space-x-2">
                  <.link
                    navigate={~p"/customers/#{customer}/edit"}
                    class="text-blue-600 hover:text-blue-800"
                  >
                    Edit
                  </.link>
                  <.link
                    phx-click={JS.push("delete", value: %{id: customer.id}) |> hide("##{id}")}
                    data-confirm="Are you sure?"
                    class="text-red-600 hover:text-red-800"
                  >
                    Delete
                  </.link>
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
    {:ok,
     socket
     |> assign(:page_title, "Customers")
     |> stream(:customers, Customers.list_customers(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    customer = Customers.get_customer!(socket.assigns.current_scope, id)
    {:ok, _} = Customers.delete_customer(socket.assigns.current_scope, customer)

    {:noreply, stream_delete(socket, :customers, customer)}
  end
end
