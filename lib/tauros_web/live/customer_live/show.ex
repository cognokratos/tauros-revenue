defmodule TaurosWeb.CustomerLive.Show do
  use TaurosWeb, :live_view

  alias Tauros.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold">{@customer.name}</h1>
          <div class="flex gap-2">
            <.link navigate={~p"/customers/#{@customer}/edit"} class="text-blue-600 hover:text-blue-800">
              Edit
            </.link>
            <.link navigate={~p"/customers"} class="text-gray-600 hover:text-gray-800">
              Back
            </.link>
          </div>
        </div>

        <div class="bg-white border rounded-lg p-6 space-y-4">
          <div>
            <p class="text-sm text-gray-600">Email</p>
            <p class="text-lg">{@customer.email}</p>
          </div>
          <div>
            <p class="text-sm text-gray-600">Agent</p>
            <p class="text-lg">{@customer.agent.name}</p>
          </div>
          <div>
            <p class="text-sm text-gray-600">Created</p>
            <p class="text-lg">{Calendar.strftime(@customer.inserted_at, "%Y-%m-%d %H:%M")}</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    customer = Customers.get_customer!(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign(:page_title, customer.name)
     |> assign(:customer, customer)}
  end
end
