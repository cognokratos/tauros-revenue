defmodule TaurosWeb.InvoiceLive.Index do
  @moduledoc """
  Every invoice the human's agents proposed, filterable by where it is in its
  lifecycle. Pending invoices say so, and link straight to their review.
  """
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  @filters [
    {"all", "All"},
    {"review", "Needs review"},
    {"draft", "Drafts"},
    {"approved", "Approved"},
    {"closed", "Rejected / cancelled"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        Invoices
        <:subtitle>
          Invoice proposals your agents created, in every state. Agents propose; a human approver decides.
        </:subtitle>
      </.header>

      <nav id="invoice-filters" aria-label="Filter invoices" class="flex flex-wrap gap-2">
        <.link
          :for={{key, label} <- @filters}
          id={"filter-#{key}"}
          patch={if key == "all", do: ~p"/invoices", else: ~p"/invoices?status=#{key}"}
          aria-current={@filter == key && "page"}
          class={["btn btn-sm", @filter == key && "btn-neutral", @filter != key && "btn-ghost"]}
        >
          {label} <span class="opacity-60">{@counts[key]}</span>
        </.link>
      </nav>

      <.table
        id="invoices"
        rows={@streams.invoices}
        row_click={fn {_id, invoice} -> JS.navigate(~p"/invoices/#{invoice}") end}
      >
        <:col :let={{_id, invoice}} label="Customer">
          <span class="font-medium">{invoice.current_revision.customer.name}</span>
          <span class="block text-xs opacity-60">from {invoice.agent.name}</span>
        </:col>
        <:col :let={{_id, invoice}} label="Amount">
          <span class="whitespace-nowrap font-mono text-sm">
            {money(invoice.current_revision.total, invoice.current_revision.currency)}
          </span>
        </:col>
        <:col :let={{_id, invoice}} label="Status"><.invoice_status invoice={invoice} /></:col>
        <:col :let={{_id, invoice}} label="Due" class="hidden md:table-cell">
          <span class="whitespace-nowrap">{invoice.current_revision.due_date}</span>
        </:col>
        <:col :let={{_id, invoice}} label="Next" class="hidden sm:table-cell">
          <%= cond do %>
            <% invoice.state == :pending_approval and @current_user.role == :approver -> %>
              <span class="text-xs font-medium">Needs your review</span>
            <% invoice.state == :pending_approval -> %>
              <span class="text-xs opacity-70">Waiting for an approver</span>
            <% match?({"Changes requested", _}, status(invoice)) -> %>
              <span class="text-xs opacity-70">Agent to revise</span>
            <% invoice.state == :draft -> %>
              <span class="text-xs opacity-70">Agent preparing</span>
            <% true -> %>
              <span class="text-xs opacity-40">—</span>
          <% end %>
        </:col>
        <:action :let={{_id, invoice}}>
          <%!-- Action cells are outside the row click, so this opens the review, not the invoice. --%>
          <.link
            :if={invoice.state == :pending_approval and @current_user.role == :approver}
            id={"review-#{invoice.id}"}
            navigate={~p"/invoices/#{invoice}/review"}
            class="btn btn-primary btn-xs"
          >
            Review
          </.link>
          <div class="sr-only">
            <.link navigate={~p"/invoices/#{invoice}"}>Show</.link>
          </div>
        </:action>
      </.table>

      <div
        :if={@empty?}
        id="empty-state"
        class="rounded-box border border-dashed border-base-300 p-8 text-center"
      >
        <p class="font-medium">{empty_title(@filter)}</p>
        <p class="mt-1 text-sm opacity-70">
          Invoice proposals created by your agents appear here. Agents create them through the REST API or MCP.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Invoices", filters: @filters)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      if params["status"] in Enum.map(@filters, &elem(&1, 0)), do: params["status"], else: "all"

    # The human's invoices, read under their policies. Filtering the loaded
    # list keeps the derived "Changes requested" status in one place.
    invoices =
      Tauros.Revenue.list_invoices!(
        actor: socket.assigns.current_user,
        load: [:agent, current_revision: [:customer, :approval]]
      )

    shown = Enum.filter(invoices, &in_filter?(&1, filter))

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(
       :counts,
       Map.new(@filters, fn {key, _} -> {key, Enum.count(invoices, &in_filter?(&1, key))} end)
     )
     |> assign(:empty?, shown == [])
     |> stream(:invoices, shown, reset: true)}
  end

  defp in_filter?(_invoice, "all"), do: true
  defp in_filter?(invoice, "review"), do: invoice.state == :pending_approval
  defp in_filter?(invoice, "draft"), do: invoice.state == :draft
  defp in_filter?(invoice, "approved"), do: invoice.state == :approved
  defp in_filter?(invoice, "closed"), do: invoice.state in [:rejected, :cancelled]

  defp empty_title("review"), do: "Nothing needs review."
  defp empty_title("all"), do: "No invoices yet."
  defp empty_title(_), do: "No invoices in this state."
end
