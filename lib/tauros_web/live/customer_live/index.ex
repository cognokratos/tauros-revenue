defmodule TaurosWeb.CustomerLive.Index do
  use TaurosWeb, :live_view

  alias Tauros.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Customers</h1>
          <.button variant="primary" navigate={~p"/customers/new"}>
            <.icon name="hero-plus" /> New Customer
          </.button>
        </div>

        <div id="customers" phx-update="stream" class="space-y-4">
          <div id="empty-state" class="hidden only:block text-center text-gray-500 py-8">
            No customers yet. Create one to get started.
          </div>
          <%= for {{id, customer}} <- @streams.customers do %>
            <div id={id} class="border rounded-lg p-4 hover:shadow-md transition-shadow">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <h3 class="font-semibold text-lg">{customer.name}</h3>
                  <p class="text-gray-600">{customer.email}</p>
                  <p class="text-sm text-gray-500 mt-2">Agent: {customer.agent.name}</p>
                </div>
                <div class="flex gap-2">
                  <.link navigate={~p"/customers/#{customer}/edit"} class="text-blue-600 hover:text-blue-800">
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
          <% end %>
        </div>
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
