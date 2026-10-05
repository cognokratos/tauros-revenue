defmodule TaurosWeb.DashboardLive do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Dashboard
        <:subtitle>What you and your agents are responsible for.</:subtitle>
      </.header>

      <div id="metrics" class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <.metric
          id="agents-metric"
          navigate={~p"/agents"}
          label="Agents"
          count={@counts.agents}
          icon="hero-cpu-chip"
        />
        <.metric
          id="customers-metric"
          navigate={~p"/customers"}
          label="Customers"
          count={@counts.customers}
          icon="hero-building-storefront"
        />
        <.metric
          id="destinations-metric"
          navigate={~p"/destinations"}
          label="Payment destinations"
          count={@counts.destinations}
          icon="hero-wallet"
        />
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :icon, :string, required: true

  defp metric(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class="card bg-base-100 border border-base-300 p-6 transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm font-medium opacity-70">{@label}</p>
          <p class="mt-2 text-3xl font-bold">{@count}</p>
        </div>
        <.icon name={@icon} class="size-8 text-primary" />
      </div>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    counts = %{
      agents: Ash.count!(Tauros.Accounts.Agent, actor: actor),
      customers: Ash.count!(Tauros.Revenue.Customer, actor: actor),
      destinations: Ash.count!(Tauros.Revenue.PaymentDestination, actor: actor)
    }

    {:ok, assign(socket, page_title: "Dashboard", counts: counts)}
  end
end
