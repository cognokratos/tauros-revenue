defmodule TaurosWeb.CustomerLive.Show do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@customer.name}
        <:subtitle>Customer {@customer.id}</:subtitle>

        <:actions>
          <.button navigate={~p"/customers"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/customers/#{@customer}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Customer
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@customer.id}</:item>

        <:item title="Name">{@customer.name}</:item>

        <:item title="Email">{@customer.email}</:item>

        <:item title="Created at">{@customer.inserted_at}</:item>

        <:item title="Updated at">{@customer.updated_at}</:item>

        <:item title="Agent">{@customer.agent.name}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Customer")
     |> assign(
       :customer,
       Ash.get!(Tauros.Revenue.Customer, id, actor: socket.assigns.current_user, load: :agent)
     )}
  end
end
