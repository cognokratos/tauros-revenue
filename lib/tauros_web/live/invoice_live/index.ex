defmodule TaurosWeb.InvoiceLive.Index do
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Invoices
        <:subtitle>
          Every invoice your agents proposed, in any state. Agents create them; you decide.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/approvals"} variant="primary">
            <.icon name="hero-inbox" /> Approvals
          </.button>
        </:actions>
      </.header>

      <.table
        id="invoices"
        rows={@streams.invoices}
        row_click={fn {_id, invoice} -> JS.navigate(~p"/invoices/#{invoice}") end}
      >
        <:col :let={{_id, invoice}} label="Customer">{invoice.current_revision.customer.name}</:col>
        <:col :let={{_id, invoice}} label="Amount">
          <span class="whitespace-nowrap font-mono text-sm">
            {money(invoice.current_revision.total, invoice.current_revision.currency)}
          </span>
        </:col>
        <:col :let={{_id, invoice}} label="State"><.state_badge state={invoice.state} /></:col>
        <:col :let={{_id, invoice}} label="Agent" class="hidden sm:table-cell">
          {invoice.agent.name}
        </:col>
        <:col :let={{_id, invoice}} label="Due" class="hidden sm:table-cell">
          {invoice.current_revision.due_date}
        </:col>
        <:action :let={{_id, invoice}}>
          <div class="sr-only">
            <.link navigate={~p"/invoices/#{invoice}"}>Show</.link>
          </div>
        </:action>
      </.table>

      <p :if={@empty?} id="empty-state" class="py-8 text-center opacity-70">
        No invoices yet. Your agents propose them through the API.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    invoices =
      Tauros.Revenue.list_invoices!(
        actor: socket.assigns.current_user,
        load: [:agent, current_revision: :customer]
      )

    {:ok,
     socket
     |> assign(:page_title, "Invoices")
     |> assign(:empty?, invoices == [])
     |> stream(:invoices, invoices)}
  end
end
