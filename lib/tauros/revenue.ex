defmodule Tauros.Revenue do
  @moduledoc """
  The financial core: who Tauros bills (`Customer`), where payments are
  received (`PaymentDestination`), and what is owed (`Invoice`, whose content
  lives in immutable `InvoiceRevision`s). Settlement will live here too.
  """
  use Ash.Domain, otp_app: :tauros, extensions: [AshJsonApi.Domain, AshAi]

  alias Tauros.Revenue.{Customer, Invoice, PaymentDestination}

  json_api do
    routes do
      base_route "/customers", Tauros.Revenue.Customer do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
      end

      base_route "/payment-destinations", Tauros.Revenue.PaymentDestination do
        index :read
        get :read
        post :create
        patch :deactivate, route: "/:id/deactivate"
      end

      base_route "/invoices", Tauros.Revenue.Invoice do
        index :read
        get :read

        post :create_draft do
          metadata fn _subject, invoice, _request ->
            %{idempotent_replay: invoice.__metadata__.idempotent_replay}
          end
        end

        patch :revise, route: "/:id/revise"
        patch :submit_for_approval, route: "/:id/submit"
        patch :withdraw, route: "/:id/withdraw"

        # Human authority. Agents reach these routes and are refused by policy.
        patch :approve, route: "/:id/approve"
        patch :reject, route: "/:id/reject"
        patch :request_changes, route: "/:id/request-changes"
        patch :cancel, route: "/:id/cancel"
      end
    end
  end

  # The reviewed AI capability surface (Epic 4), served at /mcp to agents only.
  # Exactly these eight tools, and no others: `Tauros.Authority.mcp_tools/0`
  # lists the same set.
  # There is deliberately no tool for approve, reject, request_changes or
  # cancel; the Invoice policies would refuse an agent anyway.
  tools do
    tool :list_customers, Customer, :read do
      description """
      Lists the customers of the authenticated agent: the only customers it may
      bill. Returns id and name; use the id as customer_id in create_invoice_draft.
      """

      # No `filter`: a filter on email would let a model probe for emails it
      # is not shown. Name is enough to choose; email stays out of model context.
      select [:id, :name]
      action_parameters [:sort, :limit, :offset]
    end

    tool :list_payment_destinations, PaymentDestination, :active do
      description """
      Lists the authenticated agent's ACTIVE payment destinations: where an
      invoice may be paid. Each receives one currency on one network; an invoice's
      currency must equal its destination's currency. Retired destinations are
      not listed because they cannot be used.
      """

      select [:id, :label, :currency, :network, :address, :state]
      action_parameters [:sort, :limit, :offset, :filter]
    end

    tool :list_invoices, Invoice, :read do
      description """
      Lists the authenticated agent's invoices with their state and a summary of
      the current revision (number, customer, currency, total, due date).
      States: draft, pending_approval (waiting for a human), approved, rejected,
      cancelled. Use get_invoice for the full content.
      """

      select [:id, :state, :idempotency_key, :updated_at]
      load current_revision: [:number, :customer_id, :currency, :total, :due_date]
      load_strict? true
      action_parameters [:sort, :limit, :offset, :filter]
    end

    tool :get_invoice, Invoice, :read do
      description """
      Returns one of the authenticated agent's invoices: its state and its
      current revision (customer, payment destination, currency, lines, total,
      due date, reasoning, payload hash) and, if a human has decided on that
      revision, the decision and reason. After "changes_requested", read the
      reason and call revise_invoice.
      """

      get_by :id
      select [:id, :state, :idempotency_key, :updated_at]

      load current_revision: [
             :number,
             :currency,
             :due_date,
             :lines,
             :total,
             :reasoning,
             :payload_hash,
             customer: [:name],
             payment_destination: [:label, :currency, :network, :address, :state],
             approval: [:decision, :reason, :decided_at]
           ]

      load_strict? true
    end

    tool :create_invoice_draft, Invoice, :create_draft do
      description """
      Creates an invoice PROPOSAL owned by the authenticated agent, in state
      draft. It does not approve, issue, send or pay anything. Requires an
      idempotency_key you choose: repeating the call with the same key and the
      same financial payload returns the original invoice; the same key with a
      different payload is refused. Amounts are decimal strings (e.g. "1200.50"),
      never floating-point numbers, and must fit the currency's decimal places.
      customer_id and payment_destination_id must come from list_customers and
      list_payment_destinations, and currency must equal the destination's.
      """

      # Write tools return the invoice's own fields only: AshAI 1.1 applies
      # `load` non-strictly to writes, which would return whole revisions.
      # Call get_invoice for the content and payload hash.
      select [:id, :state, :idempotency_key]
    end

    tool :revise_invoice, Invoice, :revise do
      description """
      Proposes new content for one of the agent's draft or pending invoices.
      Omitted fields keep their current values; reasoning is required. Appends a
      new immutable revision with a new payload hash and returns the invoice to
      draft: a pending invoice must be submitted again, and any human looking at
      the old revision can no longer approve it. Cannot change an approved,
      rejected or cancelled invoice.
      """

      select [:id, :state]
    end

    tool :submit_invoice, Invoice, :submit_for_approval do
      description """
      Submits the current immutable revision of one of the agent's draft
      invoices for human review (state pending_approval). This does NOT approve
      the invoice: a human approver decides. Retry-safe. Refused if a human
      already decided on this revision (revise first) or its destination was
      retired.
      """

      select [:id, :state]
    end

    tool :withdraw_invoice, Invoice, :withdraw do
      description """
      Withdraws one of the agent's undecided proposals (draft or
      pending_approval); it becomes cancelled and stays on record. It cannot
      undo a human approval. Retry-safe.
      """

      select [:id, :state]
    end
  end

  resources do
    resource Tauros.Revenue.Customer do
      define :list_customers,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :get_customer, action: :read, get_by: :id
      define :create_customer, action: :create
      define :update_customer, action: :update
      define :destroy_customer, action: :destroy
    end

    resource Tauros.Revenue.PaymentDestination do
      define :list_payment_destinations,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :get_payment_destination, action: :read, get_by: :id
      define :list_active_payment_destinations, action: :active
      define :create_payment_destination, action: :create
      define :deactivate_payment_destination, action: :deactivate
    end

    resource Tauros.Revenue.Invoice do
      define :list_invoices,
        action: :read,
        default_options: [query: [sort: [updated_at: :desc]]]

      define :get_invoice, action: :read, get_by: :id
      define :list_invoices_awaiting_approval, action: :awaiting_approval
      define :create_invoice_draft, action: :create_draft
      define :revise_invoice, action: :revise
      define :submit_invoice, action: :submit_for_approval
      define :withdraw_invoice, action: :withdraw
      define :approve_invoice, action: :approve
      define :reject_invoice, action: :reject
      define :request_invoice_changes, action: :request_changes
      define :cancel_invoice, action: :cancel
    end

    resource Tauros.Revenue.InvoiceRevision
    resource Tauros.Revenue.Approval
    resource Tauros.Revenue.InvoiceEvent
  end
end
