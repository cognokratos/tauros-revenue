defmodule TaurosWeb.InvoiceLive.Show do
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Invoice for {@invoice.current_revision.customer.name}
        <:subtitle>
          <.state_badge id="invoice-state" state={@invoice.state} />
          <span class="ml-2 font-mono text-xs">{@invoice.idempotency_key}</span>
        </:subtitle>
        <:actions>
          <.button
            :if={@invoice.state == :pending_approval}
            id="review-link"
            navigate={~p"/approvals/#{@invoice}"}
            variant="primary"
          >
            Review in approvals
          </.button>
          <.button navigate={~p"/invoices"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <div class="space-y-6">
        <.financial_intent invoice={@invoice} />

        <section :if={@invoice.approvals != []} aria-labelledby="decisions-heading">
          <h3 id="decisions-heading" class="text-sm font-semibold">Decisions</h3>
          <ul id="decisions" class="mt-2 space-y-2 text-sm">
            <li :for={approval <- @invoice.approvals} id={"approval-#{approval.id}"}>
              <span class="font-semibold">{approval.decision}</span>
              by {approval.approver.email}
              <span class="opacity-70">
                on revision {revision_number(@invoice, approval.revision_id)},
                SHA-256
                <code class="font-mono text-xs">{String.slice(approval.payload_hash, 0, 12)}…</code>
              </span>
              <p :if={approval.reason} class="opacity-80">{approval.reason}</p>
            </li>
          </ul>
        </section>

        <.history events={@invoice.events} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    invoice =
      Tauros.Revenue.get_invoice!(id,
        actor: socket.assigns.current_user,
        load: [
          :agent,
          :revisions,
          :events,
          approvals: :approver,
          current_revision: [:customer, :payment_destination]
        ]
      )

    {:ok, assign(socket, page_title: "Invoice", invoice: invoice)}
  end

  defp revision_number(invoice, revision_id),
    do: Enum.find_value(invoice.revisions, &(&1.id == revision_id && &1.number))
end
