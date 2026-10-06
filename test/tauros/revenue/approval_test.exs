defmodule Tauros.Revenue.ApprovalTest do
  @moduledoc """
  A human approval authorizes one exact, immutable revision. These tests cover
  the decision workflow; `Tauros.AdversarialTest` attacks it.
  """
  use Tauros.DataCase, async: true

  alias AshStateMachine.Errors.NoMatchingTransition
  alias Tauros.Revenue
  alias Tauros.Revenue.{Approval, Invoice}
  alias Tauros.Revenue.Errors.Conflict

  setup do
    approver = approver()
    agent = agent(approver)
    invoice = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    %{approver: approver, agent: agent, invoice: invoice, revision: current(invoice)}
  end

  defp current(invoice),
    do: Ash.load!(invoice, :current_revision, authorize?: false).current_revision

  defp decision_input(revision, extra \\ %{}),
    do: Map.merge(%{revision_id: revision.id, payload_hash: revision.payload_hash}, extra)

  defp approvals, do: Ash.read!(Approval, authorize?: false)

  defp conflict(result) do
    assert {:error, %Ash.Error.Invalid{errors: [%Conflict{code: code}]}} = result
    code
  end

  describe "approve" do
    test "authorizes the exact revision and records who, what and when", ctx do
      assert {:ok, %{state: :approved}} =
               Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision),
                 actor: ctx.approver
               )

      assert [approval] = approvals()
      assert approval.decision == :approved
      assert approval.approver_id == ctx.approver.id
      assert approval.revision_id == ctx.revision.id
      assert approval.payload_hash == ctx.revision.payload_hash
      assert %DateTime{} = approval.decided_at

      assert approval.payload_hash ==
               :sha256
               |> :crypto.hash(ctx.revision.canonical_payload)
               |> Base.encode16(case: :lower)
    end

    test "is retry-safe for the same approver: one approval, no error", ctx do
      input = decision_input(ctx.revision)
      {:ok, _} = Revenue.approve_invoice(ctx.invoice, input, actor: ctx.approver)

      assert {:ok, %{state: :approved}} =
               Revenue.approve_invoice(ctx.invoice, input, actor: ctx.approver)

      assert length(approvals()) == 1
    end

    test "requires the revision and its payload hash", ctx do
      for input <- [
            %{},
            %{revision_id: ctx.revision.id},
            %{payload_hash: ctx.revision.payload_hash}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Revenue.approve_invoice(ctx.invoice, input, actor: ctx.approver)
      end
    end

    test "a hash that is not the revision's is refused", ctx do
      wrong = decision_input(ctx.revision, %{payload_hash: String.duplicate("a", 64)})

      assert conflict(Revenue.approve_invoice(ctx.invoice, wrong, actor: ctx.approver)) ==
               :payload_mismatch

      assert Ash.get!(Invoice, ctx.invoice.id, authorize?: false).state == :pending_approval
    end
  end

  describe "reject" do
    test "refuses the proposal for good, with a reason", ctx do
      input = decision_input(ctx.revision, %{reason: "We never agreed to a retainer."})

      assert {:ok, %{state: :rejected}} =
               Revenue.reject_invoice(ctx.invoice, input, actor: ctx.approver)

      assert [%{decision: :rejected, reason: "We never agreed to a retainer."}] = approvals()
    end

    test "needs a reason", ctx do
      assert {:error, %Ash.Error.Invalid{}} =
               Revenue.reject_invoice(ctx.invoice, decision_input(ctx.revision),
                 actor: ctx.approver
               )
    end

    test "a rejected invoice cannot be revised, resubmitted or approved", ctx do
      {:ok, rejected} =
        Revenue.reject_invoice(ctx.invoice, decision_input(ctx.revision, %{reason: "No"}),
          actor: ctx.approver
        )

      assert {:error, %Ash.Error.Invalid{errors: [%NoMatchingTransition{}]}} =
               Revenue.revise_invoice(rejected, %{reasoning: "Try again"}, actor: ctx.agent)

      assert {:error, %Ash.Error.Invalid{errors: [%NoMatchingTransition{}]}} =
               Revenue.submit_invoice(rejected, actor: ctx.agent)

      assert conflict(
               Revenue.approve_invoice(rejected, decision_input(ctx.revision),
                 actor: ctx.approver
               )
             ) == :already_decided
    end
  end

  describe "request_changes" do
    test "returns the invoice to the agent, who must revise before resubmitting", ctx do
      input = decision_input(ctx.revision, %{reason: "Use the Arbitrum destination."})
      {:ok, draft} = Revenue.request_invoice_changes(ctx.invoice, input, actor: ctx.approver)
      assert draft.state == :draft

      # The decided revision cannot be put in front of a human again as is.
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               Revenue.submit_invoice(draft, actor: ctx.agent)

      assert error.message =~ "revise the invoice before submitting it again"

      arbitrum = payment_destination(ctx.agent, %{network: :arbitrum})

      {:ok, revised} =
        Revenue.revise_invoice(
          draft,
          %{payment_destination_id: arbitrum.id, reasoning: "Moved to Arbitrum as asked."},
          actor: ctx.agent
        )

      pending = Revenue.submit_invoice!(revised, actor: ctx.agent)
      second = current(pending)
      assert second.number == 2

      assert {:ok, %{state: :approved}} =
               Revenue.approve_invoice(pending, decision_input(second), actor: ctx.approver)

      assert approvals() |> Enum.map(&{&1.revision_id, &1.decision}) |> Enum.sort() ==
               Enum.sort([{ctx.revision.id, :changes_requested}, {second.id, :approved}])
    end
  end

  describe "cancel" do
    setup ctx do
      {:ok, approved} =
        Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision), actor: ctx.approver)

      %{approved: approved}
    end

    test "an approver cancels an approved invoice before issue, with a reason", ctx do
      assert {:ok, %{state: :cancelled}} =
               Revenue.cancel_invoice(ctx.approved, %{reason: "Customer churned"},
                 actor: ctx.approver
               )
    end

    test "an agent cannot undo an approval by withdrawing or revising", ctx do
      assert {:error, %Ash.Error.Invalid{errors: [%NoMatchingTransition{}]}} =
               Revenue.withdraw_invoice(ctx.approved, actor: ctx.agent)

      assert {:error, %Ash.Error.Invalid{errors: [%NoMatchingTransition{}]}} =
               Revenue.revise_invoice(ctx.approved, %{reasoning: "Edit after approval"},
                 actor: ctx.agent
               )
    end
  end

  describe "an approval binds one immutable revision" do
    test "a revision submitted, then replaced, can no longer be approved", ctx do
      stale = ctx.revision

      {:ok, _} =
        Revenue.revise_invoice(
          ctx.invoice,
          %{due_date: Date.add(Date.utc_today(), 90), reasoning: "Customer asked for 90 days"},
          actor: ctx.agent
        )

      resubmitted = Revenue.submit_invoice!(ctx.invoice, actor: ctx.agent)

      assert conflict(
               Revenue.approve_invoice(resubmitted, decision_input(stale), actor: ctx.approver)
             ) == :stale_revision

      assert {:ok, %{state: :approved}} =
               Revenue.approve_invoice(resubmitted, decision_input(current(resubmitted)),
                 actor: ctx.approver
               )

      assert [%{revision_id: approved_id}] = approvals()
      refute approved_id == stale.id
    end

    test "approved content cannot change: there is no path to edit a revision", ctx do
      {:ok, approved} =
        Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision), actor: ctx.approver)

      assert Ash.Resource.Info.actions(Revenue.InvoiceRevision)
             |> Enum.map(& &1.type)
             |> Enum.sort() ==
               [:create, :read]

      assert Ash.Resource.Info.actions(Approval) |> Enum.map(& &1.type) |> Enum.sort() ==
               [:create, :read]

      assert current(approved).payload_hash == ctx.revision.payload_hash
    end

    test "a revision altered behind Tauros's back is never approved", ctx do
      Repo.query!("UPDATE invoice_revisions SET due_date = due_date + 1 WHERE id = $1", [
        Ecto.UUID.dump!(ctx.revision.id)
      ])

      assert conflict(
               Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision),
                 actor: ctx.approver
               )
             ) == :payload_integrity
    end
  end

  describe "a destination retired while approval is pending" do
    setup ctx do
      destination =
        Ash.get!(Revenue.PaymentDestination, ctx.revision.payment_destination_id,
          authorize?: false
        )

      {:ok, _} = Revenue.deactivate_payment_destination(destination, actor: ctx.agent)
      :ok
    end

    test "blocks approval and forces a new revision", ctx do
      assert conflict(
               Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision),
                 actor: ctx.approver
               )
             ) == :destination_inactive

      assert {:ok, %{state: :draft}} =
               Revenue.request_invoice_changes(
                 ctx.invoice,
                 decision_input(ctx.revision, %{reason: "Destination retired; pick another."}),
                 actor: ctx.approver
               )
    end
  end

  describe "concurrent decisions on one invoice" do
    test "the second of two decisions made from stale copies is refused", ctx do
      # Two browser tabs loaded the same pending invoice.
      tab_one = ctx.invoice
      tab_two = ctx.invoice

      {:ok, _} =
        Revenue.approve_invoice(tab_one, decision_input(ctx.revision), actor: ctx.approver)

      assert conflict(
               Revenue.reject_invoice(tab_two, decision_input(ctx.revision, %{reason: "No"}),
                 actor: ctx.approver
               )
             ) == :already_decided

      assert [%{decision: :approved}] = approvals()
    end

    test "the database allows one decision per revision, whatever the code does", ctx do
      {:ok, _} =
        Revenue.approve_invoice(ctx.invoice, decision_input(ctx.revision), actor: ctx.approver)

      assert_raise Postgrex.Error, ~r/approvals_one_decision_per_revision_index/, fn ->
        Repo.query!(
          """
          INSERT INTO approvals (invoice_id, revision_id, approver_id, decision, payload_hash)
          VALUES ($1, $2, $3, 'approved', $4)
          """,
          [
            Ecto.UUID.dump!(ctx.invoice.id),
            Ecto.UUID.dump!(ctx.revision.id),
            Ecto.UUID.dump!(ctx.approver.id),
            ctx.revision.payload_hash
          ]
        )
      end
    end
  end

  describe "reading decisions" do
    test "the proposing agent can read the decisions on its invoices", ctx do
      {:ok, _} =
        Revenue.request_invoice_changes(
          ctx.invoice,
          decision_input(ctx.revision, %{reason: "Wrong customer"}),
          actor: ctx.approver
        )

      assert [%{reason: "Wrong customer"}] = Ash.read!(Approval, actor: ctx.agent)
      assert [] = Ash.read!(Approval, actor: agent(ctx.approver))
      assert [] = Ash.read!(Approval, actor: user())
    end
  end
end
