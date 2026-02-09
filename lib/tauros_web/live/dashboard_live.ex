defmodule TaurosWeb.DashboardLive do
  use TaurosWeb, :live_view

  alias Tauros.Agents
  alias Tauros.Customers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> load_metrics()}
  end

  defp load_metrics(socket) do
    current_scope = socket.assigns.current_scope
    current_user = current_scope.user

    agents_count = Agents.list_agents_for_user(current_user.id) |> length()
    customers_count = Customers.list_customers(current_scope) |> length()

    # Placeholder counts for clients and invoices (to be implemented)
    pending_invoices_count = 0
    approved_invoices_count = 0

    assign(socket,
      agents_count: agents_count,
      customers_count: customers_count,
      pending_invoices_count: pending_invoices_count,
      approved_invoices_count: approved_invoices_count
    )
  end
end
