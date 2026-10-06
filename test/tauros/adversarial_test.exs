defmodule Tauros.AdversarialTest do
  @moduledoc """
  Tauros teaches through failed attacks. Each test attempts something an agent,
  a buggy client or a careless human might try, and names the guard that stops
  it: a policy, a state-machine rule, a validation, a unique index, a lock, or
  the immutable model itself.

  The success criterion of the learning phase:

  > An agent can prepare a proposal, select only resources it is allowed to
  > use, explain its reasoning and submit it. A human sees the exact immutable
  > intent and approves it. The agent cannot obtain that approval itself
  > through direct Ash calls, REST calls, manipulated state, retries or
  > another interface.

  REST variants of these attacks are in `TaurosWeb.Api.InvoicesTest`, and UI
  variants in `TaurosWeb.InvoiceReviewLiveTest` and `TaurosWeb.AdversarialLiveTest`.
  """
  use Tauros.DataCase, async: true

  alias AshStateMachine.Errors.NoMatchingTransition
  alias Tauros.Revenue
  alias Tauros.Revenue.{Approval, Invoice, InvoiceEvent, InvoiceRevision}
  alias Tauros.Revenue.Errors.Conflict

  setup do
    approver = approver()
    agent = agent(approver)
    pending = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    revision = Ash.load!(pending, :current_revision, authorize?: false).current_revision

    %{
      approver: approver,
      agent: agent,
      pending: pending,
      revision: revision,
      decision: %{revision_id: revision.id, payload_hash: revision.payload_hash}
    }
  end

  defp state(invoice), do: Ash.get!(Invoice, invoice.id, authorize?: false).state
  defp approvals, do: Ash.read!(Approval, authorize?: false)

  defp forge_approval(ctx, actor) do
    Approval
    |> Ash.Changeset.for_create(:create, Map.put(ctx.decision, :decision, :approved),
      actor: actor
    )
    |> Ash.Changeset.force_change_attribute(:invoice_id, ctx.pending.id)
    |> Ash.create()
  end

  defp conflict_code({:error, %Ash.Error.Invalid{errors: [%Conflict{code: code} | _]}}), do: code
  defp conflict_code(other), do: other

  defp illegal_transition?({:error, %Ash.Error.Invalid{errors: errors}}),
    do: Enum.any?(errors, &match?(%NoMatchingTransition{}, &1))

  defp illegal_transition?(_), do: false

  describe "authority escalation" do
    test "an agent calls the approve action directly", ctx do
      # Guard: Invoice policy `forbid_unless HumanApprover` on :approve.
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.agent)

      assert state(ctx.pending) == :pending_approval
      assert approvals() == []
    end

    test "an agent calls every other authority action directly", ctx do
      # Guard: the same policy covers :reject, :request_changes and :cancel.
      input = Map.put(ctx.decision, :reason, "I decide")

      for fun <- [&Revenue.reject_invoice/3, &Revenue.request_invoice_changes/3] do
        assert {:error, %Ash.Error.Forbidden{}} = fun.(ctx.pending, input, actor: ctx.agent)
      end

      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.cancel_invoice(ctx.pending, %{reason: "x"}, actor: ctx.agent)
    end

    test "an agent writes an Approval record itself", ctx do
      # Guard: Approval create policy: `accessing_from(Invoice, :approvals)` and
      # `HumanApprover`. A second, independent layer: even if the Invoice policy
      # were wrong, no agent could create the record.
      # `invoice_id` is not even an accepted input; force it, as code could.
      assert {:error, %Ash.Error.Forbidden{}} = forge_approval(ctx, ctx.agent)

      assert approvals() == []
    end

    test "a human approver writes an Approval record outside the approve action", ctx do
      # Guard: `accessing_from(Invoice, :approvals)`: an approval without the
      # transition would be a decision the invoice never went through.
      # `invoice_id` is not even an accepted input; force it, as code could.
      assert {:error, %Ash.Error.Forbidden{}} = forge_approval(ctx, ctx.approver)
    end

    test "an agent forges an audit event claiming a human approved", ctx do
      # Guard: InvoiceEvent has no create policy; only RecordEvent writes events.
      forged = %{
        invoice_id: ctx.pending.id,
        action: :approve,
        to_state: :approved,
        actor_id: ctx.approver.id,
        actor_kind: :human,
        interface: :ui
      }

      assert {:error, %Ash.Error.Forbidden{}} =
               InvoiceEvent
               |> Ash.Changeset.for_create(:record, forged, actor: ctx.agent)
               |> Ash.create()
    end

    test "an agent smuggles decision fields into its own actions", ctx do
      # Guard: accept lists and arguments. Agent actions have no way to express
      # an approval, a state or an approver.
      for extra <- [
            %{state: :approved},
            %{approvals: [Map.put(ctx.decision, :decision, :approved)]},
            %{approver_id: ctx.approver.id}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Revenue.revise_invoice(ctx.pending, Map.put(extra, :reasoning, "x"),
                   actor: ctx.agent
                 )
      end

      assert approvals() == []
    end

    test "an operator owns the agent but cannot approve its invoice" do
      # Guard: HumanApprover requires `role: :approver`; owning the agent is not enough.
      operator = user()
      agent = agent(operator)
      invoice = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
      revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision

      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.approve_invoice(
                 invoice,
                 %{revision_id: revision.id, payload_hash: revision.payload_hash},
                 actor: operator
               )
    end

    test "an approver cannot approve another human's agents' invoices", ctx do
      # Guard: `relates_to_actor_via([:agent, :user])` in the same policy.
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.approve_invoice(ctx.pending, ctx.decision, actor: approver())
    end

    test "an agent tries to create or promote a human approver", ctx do
      # Guard: User policies: invite needs HumanApprover; bootstrap forbids agents.
      assert {:error, %Ash.Error.Forbidden{}} =
               Tauros.Accounts.invite_user("ai@example.com", :approver, actor: ctx.agent)

      assert {:error, %Ash.Error.Forbidden{}} =
               Tauros.Accounts.bootstrap_approver("ai@example.com", actor: ctx.agent)
    end

    test "an agent tries to register another agent or rotate keys", ctx do
      # Guard: Agent policy `forbid_unless HumanActor`.
      assert {:error, %Ash.Error.Forbidden{}} =
               Tauros.Accounts.create_agent("Shadow agent", actor: ctx.agent)

      assert {:error, %Ash.Error.Forbidden{}} =
               Tauros.Accounts.rotate_agent_api_key(ctx.agent, actor: ctx.agent)
    end
  end

  describe "state manipulation" do
    test "the agent tries to set state = approved", ctx do
      # Guard: no action accepts `state`; it changes only through transitions.
      assert {:error, %Ash.Error.Invalid{}} =
               ctx.agent
               |> draft_input(state: :approved)
               |> Revenue.create_invoice_draft(actor: ctx.agent)

      assert {:error, %Ash.Error.Invalid{}} =
               ctx.pending
               |> Ash.Changeset.for_update(:submit_for_approval, %{state: :approved},
                 actor: ctx.agent
               )
               |> Ash.update()

      assert state(ctx.pending) == :pending_approval
    end

    test "approving a draft that skipped pending_approval", ctx do
      # Guard: state machine: :approve only from :pending_approval.
      draft = invoice_draft(ctx.agent)
      revision = Ash.load!(draft, :current_revision, authorize?: false).current_revision

      assert illegal_transition?(
               Revenue.approve_invoice(
                 draft,
                 %{revision_id: revision.id, payload_hash: revision.payload_hash},
                 actor: ctx.approver
               )
             )
    end

    test "approving a rejected invoice", ctx do
      # Guard: one decision per revision (Decide + unique index); rejected is terminal.
      {:ok, rejected} =
        Revenue.reject_invoice(ctx.pending, Map.put(ctx.decision, :reason, "No"),
          actor: ctx.approver
        )

      assert conflict_code(Revenue.approve_invoice(rejected, ctx.decision, actor: ctx.approver)) ==
               :already_decided

      assert state(rejected) == :rejected
    end

    test "approving a cancelled invoice", ctx do
      # Guard: state machine: no transition out of :cancelled.
      {:ok, cancelled} = Revenue.withdraw_invoice(ctx.pending, actor: ctx.agent)

      assert illegal_transition?(
               Revenue.approve_invoice(cancelled, ctx.decision, actor: ctx.approver)
             )
    end

    test "a stale in-memory copy claims a state the database no longer has", ctx do
      # Guard: Transition/Decide lock the row and check the current state.
      stale = ctx.pending
      {:ok, _} = Revenue.withdraw_invoice(ctx.pending, actor: ctx.agent)

      assert illegal_transition?(
               Revenue.approve_invoice(stale, ctx.decision, actor: ctx.approver)
             )
    end
  end

  describe "cross-tenant access" do
    test "agent A uses agent B's customer or destination", ctx do
      # Guard: InvoiceRevision validation UsableReferences (ids loaded and compared).
      other = agent(user())

      for attrs <- [
            %{customer_id: customer(other).id},
            %{payment_destination_id: payment_destination(other).id}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 ctx.agent |> draft_input(attrs) |> Revenue.create_invoice_draft(actor: ctx.agent)
      end

      assert Ash.count!(Invoice, authorize?: false) == 1
    end

    test "agent A revises its invoice to point at agent B's records", ctx do
      # Guard: the same validation runs for every revision, not only the first.
      other = agent(user())

      assert {:error, %Ash.Error.Invalid{}} =
               Revenue.revise_invoice(
                 ctx.pending,
                 %{payment_destination_id: payment_destination(other).id, reasoning: "x"},
                 actor: ctx.agent
               )
    end

    test "human A reads human B's invoices, revisions, decisions and history", ctx do
      # Guard: read policies `relates_to_actor_via([..., :agent, :user])`.
      outsider = approver()

      for resource <- [Invoice, InvoiceRevision, Approval, InvoiceEvent] do
        assert Ash.read!(resource, actor: outsider) == []
      end

      assert {:error, _} = Revenue.get_invoice(ctx.pending.id, actor: outsider)
    end

    test "agent A reads agent B's invoices", ctx do
      # Guard: agent read policy `relates_to_actor_via(:agent)`.
      assert Revenue.list_invoices!(actor: agent(ctx.approver)) == []
    end
  end

  describe "idempotency" do
    test "same key, same payload: the same invoice", ctx do
      # Guard: ProposeRevision replay (agent row lock + payload hash comparison).
      input = draft_input(ctx.agent)
      first = Revenue.create_invoice_draft!(input, actor: ctx.agent)
      assert Revenue.create_invoice_draft!(input, actor: ctx.agent).id == first.id
    end

    test "same key, different payload: a deterministic conflict", ctx do
      # Guard: ProposeRevision conflict; unique index (agent_id, idempotency_key).
      input = draft_input(ctx.agent)
      Revenue.create_invoice_draft!(input, actor: ctx.agent)

      assert conflict_code(
               Revenue.create_invoice_draft(%{input | due_date: Date.add(input.due_date, 7)},
                 actor: ctx.agent
               )
             ) == :idempotency_conflict
    end

    test "concurrent duplicate draft creation produces one invoice", ctx do
      # Guard: the agent row lock serializes the lookup and the insert; the
      # unique index is the backstop.
      input = draft_input(ctx.agent)

      ids =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn -> Revenue.create_invoice_draft!(input, actor: ctx.agent).id end)
        end)
        |> Task.await_many()

      assert ids |> Enum.uniq() |> length() == 1

      assert Invoice
             |> Ash.Query.filter_input(idempotency_key: input.idempotency_key)
             |> Ash.count!(authorize?: false) == 1
    end
  end

  describe "revision safety" do
    test "revision A submitted, B becomes current, approval of A is refused", ctx do
      # Guard: Decide requires the current revision (409 stale_revision).
      {:ok, _} =
        Revenue.revise_invoice(
          ctx.pending,
          %{
            lines: [%{description: "Implementation days", quantity: "10", unit_amount: "400"}],
            reasoning: "Bigger scope"
          },
          actor: ctx.agent
        )

      Revenue.submit_invoice!(ctx.pending, actor: ctx.agent)

      assert conflict_code(
               Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)
             ) ==
               :stale_revision

      assert approvals() == []
    end

    test "a revision id from another invoice is refused", ctx do
      # Guard: Decide only accepts this invoice's current revision.
      other = ctx.agent |> invoice_draft() |> Revenue.submit_invoice!(actor: ctx.agent)

      assert conflict_code(Revenue.approve_invoice(other, ctx.decision, actor: ctx.approver)) ==
               :stale_revision
    end

    test "the approved payload is edited in the database afterwards", ctx do
      # Guard: revisions are immutable in Tauros; tampering is detectable
      # because the hash no longer matches. (Epic 5 adds database-level
      # append-only enforcement.)
      {:ok, _} = Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)

      Repo.query!("UPDATE invoice_revisions SET due_date = due_date + 30 WHERE id = $1", [
        Ecto.UUID.dump!(ctx.revision.id)
      ])

      revision = Ash.get!(InvoiceRevision, ctx.revision.id, authorize?: false)

      destination =
        Ash.get!(Revenue.PaymentDestination, revision.payment_destination_id, authorize?: false)

      [approval] = approvals()

      refute Revenue.FinancialPayload.seal(revision, destination) |> elem(1) ==
               approval.payload_hash
    end
  end

  describe "destination safety" do
    test "a destination deactivated before approval", ctx do
      # Guard: Decide locks the destination and requires it to be active.
      destination =
        Ash.get!(Revenue.PaymentDestination, ctx.revision.payment_destination_id,
          authorize?: false
        )

      {:ok, _} = Revenue.deactivate_payment_destination(destination, actor: ctx.agent)

      assert conflict_code(
               Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)
             ) ==
               :destination_inactive
    end

    test "a destination of another agent of the same human", ctx do
      # Guard: UsableReferences compares agent ids, not human ownership.
      sibling_destination = payment_destination(agent(ctx.approver))

      assert {:error, %Ash.Error.Invalid{}} =
               ctx.agent
               |> draft_input(payment_destination_id: sibling_destination.id)
               |> Revenue.create_invoice_draft(actor: ctx.agent)
    end

    test "an asset the destination does not receive", ctx do
      # Guard: UsableReferences: the invoice currency must be the destination's.
      usdc = payment_destination(ctx.agent, %{currency: :USDC, network: :base})

      assert {:error, %Ash.Error.Invalid{errors: [%{field: :currency}]}} =
               ctx.agent
               |> draft_input(destination: usdc, currency: :ETH)
               |> Revenue.create_invoice_draft(actor: ctx.agent)
    end
  end

  describe "concurrency" do
    test "two simultaneous approval attempts produce one approval", ctx do
      # Guard: invoice row lock in Decide; replay for the same approver; unique
      # index on approvals.revision_id as the backstop.
      results =
        1..3
        |> Enum.map(fn _ ->
          Task.async(fn ->
            Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)
          end)
        end)
        |> Task.await_many()

      assert Enum.all?(results, &match?({:ok, %{state: :approved}}, &1))
      assert length(approvals()) == 1
    end

    test "approve and reject race: exactly one wins", ctx do
      # Guard: one decision per revision.
      results =
        [
          fn -> Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver) end,
          fn ->
            Revenue.reject_invoice(ctx.pending, Map.put(ctx.decision, :reason, "No"),
              actor: ctx.approver
            )
          end
        ]
        |> Enum.map(&Task.async/1)
        |> Task.await_many()

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert [winner] = approvals()

      assert state(ctx.pending) ==
               if(winner.decision == :approved, do: :approved, else: :rejected)
    end

    test "retry after a timeout: the approval is not repeated", ctx do
      # Guard: Decide replay (same approver, decision and hash).
      {:ok, _} = Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)
      # The client never saw the response and sends the same command again.
      assert {:ok, %{state: :approved}} =
               Revenue.approve_invoice(ctx.pending, ctx.decision, actor: ctx.approver)

      assert length(approvals()) == 1
    end
  end
end
