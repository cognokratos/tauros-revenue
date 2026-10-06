defmodule TaurosWeb.InvoiceLive.Review do
  @moduledoc """
  "Needs review": the invoices waiting for a human decision, and the review of
  one of them ("Quiet Ledger"). Reviewing is a step of an invoice's lifecycle,
  so it lives under /invoices.

  The decision form carries the `revision_id` and `payload_hash` that were on
  screen. If the proposal changed in the meantime, the domain refuses the
  decision (`stale_revision`) and the human reviews the new revision. Whether
  the viewer may decide is asked of the domain (`Ash.can?/2`); the policies
  enforce it either way.
  """
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  alias Tauros.Revenue
  alias Tauros.Revenue.Errors.Conflict

  @detail [
    :agent,
    :revisions,
    :events,
    current_revision: [:customer, :payment_destination, :approval]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        Needs review
        <:subtitle>
          Proposals your agents submitted. Nothing is approved until a human approver decides, one at a time.
        </:subtitle>
      </.header>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
        <section aria-label="Pending proposals" class={[@invoice && "hidden lg:block"]}>
          <div id="pending-proposals" phx-update="stream" class="space-y-3">
            <div :for={{id, invoice} <- @streams.pending} id={id}>
              <.proposal_card
                invoice={invoice}
                patch={~p"/invoices/#{invoice}/review"}
                selected?={@invoice && @invoice.id == invoice.id}
              />
            </div>
          </div>
          <div
            :if={@pending_count == 0}
            id="empty-state"
            class="rounded-box border border-dashed border-base-300 p-8 text-center"
          >
            <p class="font-medium">Nothing needs your review.</p>
            <p class="mt-1 text-sm opacity-70">
              When an agent submits a proposal, it appears here.
              <.link navigate={~p"/invoices"} class="link">See all invoices</.link>
            </p>
          </div>
        </section>

        <p
          :if={!@invoice and @pending_count > 0}
          id="select-prompt"
          class="hidden self-start rounded-box border border-dashed border-base-300 p-8 text-center text-sm opacity-70 lg:block"
        >
          Select a proposal to see exactly what approving it would authorize.
        </p>

        <section :if={@invoice} id="proposal" aria-label="Selected proposal" class="space-y-6">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <.link patch={~p"/invoices/review"} class="btn btn-ghost btn-sm lg:hidden">
              <.icon name="hero-arrow-left" /> All proposals
            </.link>
            <.link
              id="open-invoice"
              navigate={~p"/invoices/#{@invoice}"}
              class="link link-hover ml-auto text-sm"
            >
              Open the invoice <.icon name="hero-arrow-right" class="size-3" />
            </.link>
          </div>

          <div
            id="authority"
            class="grid gap-3 rounded-box border border-base-300 bg-base-100 p-4 text-sm sm:grid-cols-2"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide opacity-60">Proposed by</p>
              <p><span class="font-semibold">{@invoice.agent.name}</span>, an AI agent</p>
              <p class="text-xs opacity-70">It can prepare and submit; it cannot approve.</p>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide opacity-60">
                Decision authority
              </p>
              <p :if={@can_decide?} id="decision-authority">
                <span class="font-semibold">You</span>, a human approver
              </p>
              <p :if={!@can_decide?} id="decision-authority">
                A human approver (not you: your role is {@current_user.role})
              </p>
            </div>
          </div>

          <.financial_intent invoice={@invoice} summary_label="What approving authorizes" />

          <div
            :if={@invoice.current_revision.payment_destination.state != :active}
            id="destination-warning"
            role="alert"
            class="alert alert-warning"
          >
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <span>
              This destination was {@invoice.current_revision.payment_destination.state} after the
              proposal was submitted. It cannot be approved; request changes so the agent proposes
              a new revision.
            </span>
          </div>

          <.decision_panel
            :if={@can_decide?}
            invoice={@invoice}
            approvable?={@invoice.current_revision.payment_destination.state == :active}
          />

          <p
            :if={@invoice.state != :pending_approval}
            id="not-pending"
            class="rounded-box border border-base-300 p-4 text-sm"
          >
            This invoice is <.invoice_status invoice={@invoice} />; there is nothing to decide.
            <.link navigate={~p"/invoices/#{@invoice}"} class="link">Open the invoice</.link>
          </p>

          <p
            :if={@invoice.state == :pending_approval and !@can_decide?}
            id="review-only"
            class="rounded-box border border-base-300 p-4 text-sm"
          >
            You can review this proposal. Only an approver can decide; your role is {@current_user.role}.
          </p>

          <.revision_details invoice={@invoice} />
          <.history events={@invoice.events} agent_names={@agent_names} viewer={@current_user} />
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :invoice, :map, required: true
  attr :approvable?, :boolean, required: true

  defp decision_panel(assigns) do
    assigns = assign(assigns, :revision, assigns.invoice.current_revision)

    ~H"""
    <section
      id="decision-panel"
      aria-labelledby="decision-heading"
      class="space-y-4 rounded-box border-2 border-base-300 bg-base-100 p-4"
    >
      <h3 id="decision-heading" class="font-semibold">Your decision</h3>

      <.form
        :if={@approvable?}
        for={%{}}
        as={:approval}
        id="approve-form"
        phx-submit="approve"
        class="space-y-3"
      >
        <input type="hidden" name="approval[revision_id]" value={@revision.id} />
        <input type="hidden" name="approval[payload_hash]" value={@revision.payload_hash} />
        <p class="text-sm">
          You are approving <strong>revision {@revision.number}</strong>
          exactly as shown above. If the agent changes anything, that becomes a new revision that
          needs its own review. Approving does not send or issue anything yet.
          <span class="block pt-1 text-xs opacity-70">
            Fingerprint <code class="font-mono">{String.slice(@revision.payload_hash, 0, 12)}…</code>
          </span>
        </p>
        <.input
          type="textarea"
          name="approval[reason]"
          id="approval_reason"
          value=""
          label="Note (optional)"
        />
        <button
          id="approve-button"
          type="submit"
          class="btn btn-primary w-full sm:w-auto"
          phx-disable-with="Approving..."
        >
          Approve {money(@revision.total, @revision.currency)}
        </button>
      </.form>

      <.form for={%{}} as={:decision} id="decline-form" phx-submit="decline" class="space-y-3">
        <input type="hidden" name="decision[revision_id]" value={@revision.id} />
        <input type="hidden" name="decision[payload_hash]" value={@revision.payload_hash} />
        <.input
          type="textarea"
          name="decision[reason]"
          id="decision_reason"
          value=""
          label="Reason (required to request changes or reject)"
        />
        <div class="flex flex-col gap-2 sm:flex-row">
          <button
            id="request-changes-button"
            type="submit"
            name="outcome"
            value="request_changes"
            class="btn btn-outline"
          >
            Request changes
          </button>
          <button
            id="reject-button"
            type="submit"
            name="outcome"
            value="reject"
            class="btn btn-outline btn-error"
          >
            Reject
          </button>
        </div>
        <p class="text-xs opacity-70">
          Request changes sends it back to the agent to revise. Reject closes it for good.
        </p>
      </.form>
    </section>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Needs review")
     |> assign(:invoice, nil)
     |> assign(:can_decide?, false)
     |> assign(:agent_names, agent_names(socket.assigns.current_user))
     |> stream_pending()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Revenue.get_invoice(id, actor: socket.assigns.current_user, load: @detail) do
      {:ok, invoice} ->
        {:noreply, socket |> select(invoice) |> stream_pending()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "That proposal is not available")
         |> push_patch(to: ~p"/invoices/review")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(invoice: nil, can_decide?: false, page_title: "Needs review")
     |> stream_pending()}
  end

  @impl true
  def handle_event("approve", %{"approval" => params}, socket) do
    decide(socket, :approve, params)
  end

  def handle_event("decline", %{"decision" => params, "outcome" => outcome}, socket)
      when outcome in ["request_changes", "reject"] do
    decide(socket, String.to_existing_atom(outcome), params)
  end

  defp decide(%{assigns: %{invoice: nil}} = socket, _outcome, _params),
    do: {:noreply, put_flash(socket, :error, "Select a proposal first.")}

  defp decide(socket, outcome, params) do
    input = %{
      revision_id: params["revision_id"],
      payload_hash: params["payload_hash"],
      reason: blank_to_nil(params["reason"])
    }

    opts = [actor: socket.assigns.current_user, context: %{interface: :ui}]

    case apply(Revenue, function(outcome), [socket.assigns.invoice, input, opts]) do
      {:ok, invoice} ->
        # Show the result where it lives: the invoice, with its new state.
        {:noreply,
         socket
         |> put_flash(:info, done(outcome))
         |> push_navigate(to: ~p"/invoices/#{invoice}")}

      {:error, error} ->
        {:noreply, socket |> put_flash(:error, explain(error)) |> reload()}
    end
  end

  defp function(:approve), do: :approve_invoice
  defp function(:reject), do: :reject_invoice
  defp function(:request_changes), do: :request_invoice_changes

  defp done(:approve), do: "Approved. Nothing has been issued or paid yet."
  defp done(:reject), do: "Rejected. The invoice is closed."
  defp done(:request_changes), do: "Sent back to the agent with your reason."

  defp explain(%Ash.Error.Invalid{errors: [%Conflict{code: code} | _]})
       when code in [:stale_revision, :already_decided] do
    "This proposal changed while you were reviewing it. Nothing was decided; review it again."
  end

  defp explain(%Ash.Error.Invalid{errors: [%Conflict{code: :destination_inactive} | _]}),
    do: "The destination was retired. Request changes instead."

  defp explain(%Ash.Error.Invalid{errors: [%Conflict{code: :payload_integrity} | _]}),
    do: "This revision no longer matches its sealed payload. Nothing was approved."

  defp explain(%Ash.Error.Invalid{errors: [%AshStateMachine.Errors.NoMatchingTransition{} | _]}),
    do: "This proposal is no longer waiting for a decision."

  defp explain(%Ash.Error.Forbidden{}), do: "Only an approver can decide on this proposal."

  defp explain(%Ash.Error.Invalid{errors: errors}) do
    if Enum.any?(errors, &(Map.get(&1, :field) == :reason)),
      do: "Give a reason so the agent knows what to change.",
      else: "The decision could not be recorded."
  end

  defp reload(socket) do
    case Revenue.get_invoice(socket.assigns.invoice.id,
           actor: socket.assigns.current_user,
           load: @detail
         ) do
      {:ok, invoice} -> socket |> select(invoice) |> stream_pending()
      _ -> socket
    end
  end

  defp select(socket, invoice) do
    revision = invoice.current_revision

    can_decide? =
      invoice.state == :pending_approval and
        Ash.can?(
          {invoice, :approve, %{revision_id: revision.id, payload_hash: revision.payload_hash}},
          socket.assigns.current_user
        )

    assign(socket,
      invoice: invoice,
      can_decide?: can_decide?,
      page_title: "Review · #{revision.customer.name}"
    )
  end

  defp stream_pending(socket) do
    pending =
      Revenue.list_invoices_awaiting_approval!(
        actor: socket.assigns.current_user,
        load: [:agent, current_revision: [:customer, :payment_destination]]
      )

    socket
    |> assign(:pending_count, length(pending))
    |> stream(:pending, pending, reset: true)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
