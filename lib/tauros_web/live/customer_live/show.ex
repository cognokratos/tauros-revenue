defmodule TaurosWeb.CustomerLive.Show do
  use TaurosWeb, :live_view

  alias Tauros.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@customer.name}
        <:actions>
          <.button navigate={~p"/customers"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/customers/#{@customer}/edit"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
        <:subtitle>
          {@customer.id}
        </:subtitle>
      </.header>

      <.card>
        <div class="px-4 py-5 sm:px-6 space-y-4">
          <div>
            <p class="text-sm text-gray-600">Email</p>
            <p class="text-lg font-medium">{@customer.email}</p>
          </div>
          <div>
            <p class="text-sm text-gray-600">Agent</p>
            <p class="text-lg font-medium">{@customer.agent.name}</p>
          </div>
          <div>
            <p class="text-sm text-gray-600">Created</p>
            <p class="text-lg">{Calendar.strftime(@customer.inserted_at, "%Y-%m-%d %H:%M")}</p>
          </div>
        </div>
      </.card>
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
