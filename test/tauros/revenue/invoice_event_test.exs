defmodule Tauros.Revenue.InvoiceEventTest do
  @moduledoc """
  The audit envelope must explain any invoice after the fact: who proposed it
  and why, what exact payload was reviewed, who decided and which revision
  and hash they authorized.
  """
  use Tauros.DataCase, async: true

  alias Tauros.Revenue
  alias Tauros.Revenue.InvoiceEvent

  setup do
    approver = approver()
    %{approver: approver, agent: agent(approver)}
  end

  defp events(invoice) do
    Ash.load!(invoice, :events, authorize?: false).events
  end

  defp decide(invoice, fun, approver, extra \\ %{}) do
    revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision

    input =
      Map.merge(%{revision_id: revision.id, payload_hash: revision.payload_hash}, extra)

    fun.(invoice, input, actor: approver)
  end

  test "a full journey can be explained from its events", %{approver: approver, agent: agent} do
    invoice = invoice_draft(agent, idempotency_key: "acme-2026-10")
    invoice = Revenue.submit_invoice!(invoice, actor: agent)

    {:ok, invoice} =
      decide(invoice, &Revenue.request_invoice_changes/3, approver, %{reason: "Wrong due date"})

    invoice =
      Revenue.revise_invoice!(
        invoice,
        %{due_date: Date.add(Date.utc_today(), 14), reasoning: "Due in 14 days, as agreed"},
        actor: agent
      )

    invoice = Revenue.submit_invoice!(invoice, actor: agent)
    {:ok, invoice} = decide(invoice, &Revenue.approve_invoice/3, approver)

    events = events(invoice)

    assert Enum.map(events, &{&1.action, &1.from_state, &1.to_state}) == [
             {:create_draft, nil, :draft},
             {:submit_for_approval, :draft, :pending_approval},
             {:request_changes, :pending_approval, :draft},
             {:revise, :draft, :draft},
             {:submit_for_approval, :draft, :pending_approval},
             {:approve, :pending_approval, :approved}
           ]

    [created, _, sent_back, revised, _, approved] = events
    [first, second] = Ash.load!(invoice, :revisions, authorize?: false).revisions

    # Who proposed it, and why?
    assert {created.actor_kind, created.actor_id} == {:agent, agent.id}
    assert created.note == "Monthly retainer agreed in the signed statement of work."
    assert created.idempotency_key == "acme-2026-10"

    # Who sent it back, and why?
    assert {sent_back.actor_kind, sent_back.actor_id} == {:human, approver.id}
    assert {sent_back.revision_id, sent_back.note} == {first.id, "Wrong due date"}

    # What exact payload was reviewed and authorized, and by whom?
    assert {revised.revision_id, revised.payload_hash} == {second.id, second.payload_hash}
    assert {approved.actor_kind, approved.actor_id} == {:human, approver.id}
    assert {approved.revision_id, approved.payload_hash} == {second.id, second.payload_hash}

    # Direct Ash calls are attributed to the console interface.
    assert Enum.all?(events, &(&1.interface == :console))
  end

  test "replays and failed commands record nothing", %{approver: approver, agent: agent} do
    input = draft_input(agent)
    invoice = Revenue.create_invoice_draft!(input, actor: agent)
    _replay = Revenue.create_invoice_draft!(input, actor: agent)
    invoice = Revenue.submit_invoice!(invoice, actor: agent)
    _replay = Revenue.submit_invoice!(invoice, actor: agent)

    wrong_hash = %{payload_hash: String.duplicate("f", 64)}
    {:error, _} = decide(invoice, &Revenue.approve_invoice/3, approver, wrong_hash)

    assert invoice |> events() |> Enum.map(& &1.action) == [:create_draft, :submit_for_approval]
  end

  test "the interface is taken from the Ash context", %{agent: agent} do
    invoice = invoice_draft(agent)

    Revenue.submit_invoice!(invoice, actor: agent, context: %{interface: :ui})

    assert invoice |> events() |> Enum.map(& &1.interface) == [:console, :ui]
  end

  describe "events are written only by invoice commands" do
    test "no actor can create one, and none can be changed", %{approver: approver, agent: agent} do
      invoice = invoice_draft(agent)

      forged = %{
        invoice_id: invoice.id,
        action: :approve,
        to_state: :approved,
        actor_id: approver.id,
        actor_kind: :human,
        interface: :ui
      }

      for actor <- [agent, approver] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 InvoiceEvent
                 |> Ash.Changeset.for_create(:record, forged, actor: actor)
                 |> Ash.create()
      end

      assert Ash.Resource.Info.actions(InvoiceEvent) |> Enum.map(& &1.type) |> Enum.sort() ==
               [:create, :read]
    end

    test "history is visible to the owners of the invoice only", %{
      approver: approver,
      agent: agent
    } do
      invoice_draft(agent)

      assert [_] = Ash.read!(InvoiceEvent, actor: approver)
      assert [_] = Ash.read!(InvoiceEvent, actor: agent)
      assert [] = Ash.read!(InvoiceEvent, actor: agent(approver))
      assert [] = Ash.read!(InvoiceEvent, actor: user())
    end
  end
end
