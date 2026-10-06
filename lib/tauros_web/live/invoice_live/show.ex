defmodule TaurosWeb.InvoiceLive.Show do
  @moduledoc """
  One invoice: where it is in its lifecycle, whose move it is, what its
  current revision states, the human decisions and the history.
  """
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  alias Tauros.Revenue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <nav aria-label="Breadcrumb" class="text-sm">
        <.link navigate={~p"/invoices"} class="link link-hover opacity-70">Invoices</.link>
        <span class="opacity-40" aria-hidden="true"> / </span>
        <span>{@invoice.current_revision.customer.name}</span>
      </nav>

      <.header>
        {@invoice.current_revision.customer.name} ·
        <span class="font-mono">
          {money(@invoice.current_revision.total, @invoice.current_revision.currency)}
        </span>
        <:subtitle>
          <.invoice_status id="invoice-state" invoice={@invoice} />
          <span class="ml-2">
            Proposed by {@invoice.agent.name} · revision {@invoice.current_revision.number} · due {@invoice.current_revision.due_date}
          </span>
        </:subtitle>
      </.header>

      <.lifecycle invoice={@invoice} />

      <.next_step
        invoice={@invoice}
        can_decide?={@can_decide?}
        viewer={@current_user}
        needs_review={@nav.needs_review}
      />

      <div class="space-y-6">
        <.financial_intent invoice={@invoice} />

        <section :if={@invoice.approvals != []} aria-labelledby="decisions-heading">
          <h3 id="decisions-heading" class="text-sm font-semibold">Human decisions</h3>
          <ul id="decisions" class="mt-2 space-y-2 text-sm">
            <li :for={approval <- @invoice.approvals} id={"approval-#{approval.id}"}>
              <span class="font-semibold">{decision_label(approval.decision)}</span>
              by {if approval.approver_id == @current_user.id, do: "you", else: "a human approver"}
              <span class="opacity-70">
                · revision {revision_number(@invoice, approval.revision_id)} · fingerprint
                <code class="font-mono text-xs">{String.slice(approval.payload_hash, 0, 12)}…</code>
              </span>
              <p :if={approval.reason} class="opacity-80">{approval.reason}</p>
            </li>
          </ul>
        </section>

        <.revision_details invoice={@invoice} />
        <.history events={@invoice.events} agent_names={@agent_names} viewer={@current_user} />
      </div>
    </Layouts.app>
    """
  end

  attr :invoice, :map, required: true
  attr :can_decide?, :boolean, required: true
  attr :viewer, :map, required: true
  attr :needs_review, :integer, required: true

  defp next_step(assigns) do
    assigns = assign(assigns, :decision, assigns.invoice.current_revision.approval)

    ~H"""
    <div id="next-step" class="rounded-box border border-base-300 bg-base-100 p-4 text-sm">
      <%= cond do %>
        <% @invoice.state == :pending_approval and @can_decide? -> %>
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <p>
              <span class="font-semibold">This proposal needs your decision.</span>
              {@invoice.agent.name} prepared it; only a human approver can approve it.
            </p>
            <.link
              id="review-link"
              navigate={~p"/invoices/#{@invoice}/review"}
              class="btn btn-primary btn-sm"
            >
              Review and decide
            </.link>
          </div>
        <% @invoice.state == :pending_approval -> %>
          <p>
            <span class="font-semibold">Waiting for a human approver.</span>
            Your role ({@viewer.role}) can review it but not decide.
          </p>
        <% @invoice.state == :draft and @decision && @decision.decision == :changes_requested -> %>
          <p>
            <span class="font-semibold">Changes requested.</span>
            Waiting for {@invoice.agent.name} to revise and resubmit it.
          </p>
          <p :if={@decision.reason} class="mt-1 opacity-80">“{@decision.reason}”</p>
        <% @invoice.state == :draft -> %>
          <p>
            <span class="font-semibold">Draft.</span>
            {@invoice.agent.name} can still revise it, then submit it for approval.
          </p>
        <% @invoice.state == :approved -> %>
          <p>
            <span class="font-semibold">Approved.</span>
            This exact revision is authorized. Nothing has been issued or paid yet; issuing comes in a later phase.
          </p>
        <% @invoice.state == :rejected -> %>
          <p><span class="font-semibold">Rejected.</span> This invoice is closed.</p>
          <p :if={@decision && @decision.reason} class="mt-1 opacity-80">“{@decision.reason}”</p>
        <% true -> %>
          <p><span class="font-semibold">Cancelled.</span> This invoice is closed.</p>
      <% end %>

      <p
        :if={@invoice.state != :pending_approval and @needs_review > 0}
        class="mt-3 border-t border-base-300 pt-3"
      >
        <.link id="next-review" navigate={~p"/invoices/review"} class="link">
          {@needs_review} {if @needs_review == 1, do: "proposal needs", else: "proposals need"} review
        </.link>
      </p>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns.current_user

    invoice =
      Revenue.get_invoice!(id,
        actor: actor,
        load: [
          :agent,
          :revisions,
          :events,
          :approvals,
          current_revision: [:customer, :payment_destination, :approval]
        ]
      )

    revision = invoice.current_revision

    can_decide? =
      invoice.state == :pending_approval and
        Ash.can?(
          {invoice, :approve, %{revision_id: revision.id, payload_hash: revision.payload_hash}},
          actor
        )

    {:ok,
     assign(socket,
       page_title: "#{revision.customer.name} · Invoice",
       invoice: invoice,
       can_decide?: can_decide?,
       agent_names: agent_names(actor)
     )}
  end

  defp decision_label(:approved), do: "Approved"
  defp decision_label(:rejected), do: "Rejected"
  defp decision_label(:changes_requested), do: "Changes requested"

  defp revision_number(invoice, revision_id),
    do: Enum.find_value(invoice.revisions, &(&1.id == revision_id && &1.number))
end
