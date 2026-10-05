defmodule Tauros.Revenue.InvoiceLifecycleTest do
  @moduledoc """
  The invoice lifecycle is the AshStateMachine `transitions` block of
  `Tauros.Revenue.Invoice`. These tests walk every legal move and try the
  illegal ones.
  """
  use Tauros.DataCase, async: true

  alias AshStateMachine.Errors.NoMatchingTransition
  alias Tauros.Revenue
  alias Tauros.Revenue.Invoice

  setup do
    owner = user()
    agent = agent(owner)
    %{owner: owner, agent: agent, invoice: invoice_draft(agent)}
  end

  defp illegal?({:error, %Ash.Error.Invalid{errors: errors}}),
    do: Enum.any?(errors, &match?(%NoMatchingTransition{}, &1))

  defp illegal?(_), do: false

  defp reload(invoice), do: Ash.get!(Invoice, invoice.id, authorize?: false, load: :revisions)

  test "state is never an input: no action accepts it" do
    for action <- Ash.Resource.Info.actions(Invoice), action.type in [:create, :update] do
      refute :state in action.accept, "#{action.name} must not accept state"
      refute Enum.any?(action.arguments, &(&1.name == :state)), "#{action.name} takes state"
    end
  end

  describe "submit_for_approval" do
    test "puts the current revision in front of a human", %{agent: agent, invoice: invoice} do
      assert {:ok, %{state: :pending_approval}} = Revenue.submit_invoice(invoice, actor: agent)
    end

    test "is retry-safe: submitting a pending invoice again changes nothing", %{
      agent: agent,
      invoice: invoice
    } do
      {:ok, pending} = Revenue.submit_invoice(invoice, actor: agent)

      assert {:ok, %{state: :pending_approval, updated_at: updated_at}} =
               Revenue.submit_invoice(invoice, actor: agent)

      assert updated_at == pending.updated_at
    end

    test "is refused once the destination is retired", %{agent: agent, invoice: invoice} do
      [revision] = reload(invoice).revisions

      destination =
        Ash.get!(Revenue.PaymentDestination, revision.payment_destination_id, authorize?: false)

      {:ok, _} = Revenue.deactivate_payment_destination(destination, actor: agent)

      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               Revenue.submit_invoice(invoice, actor: agent)

      assert error.message =~ "revise the invoice with an active destination"
      assert reload(invoice).state == :draft
    end

    test "only the proposing agent submits", %{owner: owner, invoice: invoice} do
      for actor <- [agent(owner), owner, approver()] do
        assert {:error, %Ash.Error.Forbidden{}} = Revenue.submit_invoice(invoice, actor: actor)
      end
    end
  end

  describe "revise" do
    test "a pending invoice returns to draft with a new revision", %{
      agent: agent,
      invoice: invoice
    } do
      {:ok, pending} = Revenue.submit_invoice(invoice, actor: agent)

      assert {:ok, %{state: :draft}} =
               Revenue.revise_invoice(
                 pending,
                 %{
                   due_date: Date.add(Date.utc_today(), 45),
                   reasoning: "Customer asked for 45 days"
                 },
                 actor: agent
               )

      assert length(reload(invoice).revisions) == 2
    end
  end

  describe "withdraw" do
    test "the agent withdraws a draft or a pending proposal", %{agent: agent, invoice: invoice} do
      pending = invoice_draft(agent) |> Revenue.submit_invoice!(actor: agent)

      assert {:ok, %{state: :cancelled}} = Revenue.withdraw_invoice(invoice, actor: agent)
      assert {:ok, %{state: :cancelled}} = Revenue.withdraw_invoice(pending, actor: agent)
    end

    test "the owning human may withdraw, even as an operator", %{owner: owner, invoice: invoice} do
      assert owner.role == :operator
      assert {:ok, %{state: :cancelled}} = Revenue.withdraw_invoice(invoice, actor: owner)
    end

    test "other agents and other humans may not", %{owner: owner, invoice: invoice} do
      for actor <- [agent(owner), user(), approver()] do
        assert {:error, %Ash.Error.Forbidden{}} = Revenue.withdraw_invoice(invoice, actor: actor)
      end
    end

    test "is retry-safe and keeps the invoice and its revisions", %{
      agent: agent,
      invoice: invoice
    } do
      {:ok, _} = Revenue.withdraw_invoice(invoice, actor: agent)

      assert {:ok, %{state: :cancelled}} = Revenue.withdraw_invoice(invoice, actor: agent)
      assert %{state: :cancelled, revisions: [_]} = reload(invoice)
    end
  end

  describe "illegal transitions fail for every actor" do
    test "a cancelled invoice cannot be revised, submitted or reopened", %{
      agent: agent,
      invoice: invoice
    } do
      {:ok, cancelled} = Revenue.withdraw_invoice(invoice, actor: agent)

      assert illegal?(Revenue.submit_invoice(cancelled, actor: agent))
      assert illegal?(Revenue.revise_invoice(cancelled, %{reasoning: "Reopen"}, actor: agent))
    end

    test "the check uses the current row, not the caller's stale copy", %{
      agent: agent,
      invoice: stale_draft
    } do
      {:ok, _} = Revenue.withdraw_invoice(stale_draft, actor: agent)

      # `stale_draft` still says :draft in memory; the database says :cancelled.
      assert stale_draft.state == :draft
      assert illegal?(Revenue.submit_invoice(stale_draft, actor: agent))
      assert reload(stale_draft).state == :cancelled
    end
  end
end
