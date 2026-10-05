defmodule Tauros.Revenue.InvoiceTest do
  use Tauros.DataCase, async: true

  alias Tauros.Revenue
  alias Tauros.Revenue.{FinancialPayload, Invoice, InvoiceRevision}
  alias Tauros.Revenue.Errors.Conflict

  setup do
    owner = user()
    %{owner: owner, agent: agent(owner)}
  end

  defp error_fields({:error, %{errors: errors}}),
    do: errors |> Enum.map(&Map.get(&1, :field)) |> Enum.uniq() |> Enum.sort()

  defp revisions(invoice),
    do: Ash.load!(invoice, :revisions, authorize?: false).revisions

  defp count(resource), do: Ash.count!(resource, authorize?: false)

  describe "create_invoice_draft" do
    test "an agent proposes a draft with an immutable, sealed first revision", %{agent: agent} do
      input = draft_input(agent)
      assert {:ok, invoice} = Revenue.create_invoice_draft(input, actor: agent)

      assert invoice.state == :draft
      assert invoice.agent_id == agent.id
      assert invoice.__metadata__.idempotent_replay == false

      assert [revision] = revisions(invoice)
      assert revision.number == 1
      assert revision.total == Decimal.new("1200")
      assert revision.reasoning == input.reasoning

      destination =
        Ash.get!(Revenue.PaymentDestination, input.payment_destination_id, authorize?: false)

      assert {revision.canonical_payload, revision.payload_hash} ==
               FinancialPayload.seal(revision, destination)
    end

    test "humans cannot propose invoices, whatever their role", %{owner: owner, agent: agent} do
      input = draft_input(agent)

      for actor <- [owner, approver()] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Revenue.create_invoice_draft(input, actor: actor)
      end

      # Without an actor there is nobody to own the proposal (and over HTTP the
      # API refuses with 401 before any action runs).
      assert {:error, %Ash.Error.Invalid{}} = Revenue.create_invoice_draft(input)
    end

    test "the caller cannot choose the owner, the state, the total or the hash", %{
      owner: owner,
      agent: agent
    } do
      for forged <- [
            %{agent_id: agent(owner).id},
            %{state: :approved},
            %{total: "1"},
            %{payload_hash: String.duplicate("0", 64)}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 agent |> draft_input(forged) |> Revenue.create_invoice_draft(actor: agent)
      end

      assert count(Invoice) == 0
    end
  end

  describe "idempotency" do
    test "the same key and payload return the original invoice and write nothing", %{
      agent: agent
    } do
      input = draft_input(agent)
      {:ok, first} = Revenue.create_invoice_draft(input, actor: agent)

      assert {:ok, replay} = Revenue.create_invoice_draft(input, actor: agent)
      assert replay.id == first.id
      assert replay.__metadata__.idempotent_replay == true
      assert {count(Invoice), count(InvoiceRevision)} == {1, 1}
    end

    test "a replay may word its reasoning differently; the payload is what counts", %{
      agent: agent
    } do
      input = draft_input(agent)
      {:ok, first} = Revenue.create_invoice_draft(input, actor: agent)

      retry = %{input | reasoning: "Same invoice, explained again after a timeout."}
      assert {:ok, %{id: id}} = Revenue.create_invoice_draft(retry, actor: agent)
      assert id == first.id
      assert [%{reasoning: reasoning}] = revisions(first)
      assert reasoning == input.reasoning
    end

    test "equal amounts written differently are the same payload", %{agent: agent} do
      input = draft_input(agent)
      {:ok, first} = Revenue.create_invoice_draft(input, actor: agent)

      reformatted = %{
        input
        | lines: Enum.map(input.lines, &%{&1 | unit_amount: &1.unit_amount <> ".00"})
      }

      assert {:ok, %{id: id}} = Revenue.create_invoice_draft(reformatted, actor: agent)
      assert id == first.id
    end

    test "the same key with a different payload is a conflict", %{agent: agent} do
      input = draft_input(agent)
      {:ok, _} = Revenue.create_invoice_draft(input, actor: agent)

      different = %{input | due_date: Date.add(input.due_date, 1)}

      assert {:error, %Ash.Error.Invalid{errors: [%Conflict{code: :idempotency_conflict}]}} =
               Revenue.create_invoice_draft(different, actor: agent)

      assert {count(Invoice), count(InvoiceRevision)} == {1, 1}
    end

    test "keys are scoped to the agent", %{owner: owner, agent: agent} do
      other = agent(owner)
      key = "inv-2026-001"

      {:ok, mine} =
        agent |> draft_input(idempotency_key: key) |> Revenue.create_invoice_draft(actor: agent)

      {:ok, theirs} =
        other |> draft_input(idempotency_key: key) |> Revenue.create_invoice_draft(actor: other)

      refute mine.id == theirs.id
    end

    test "a replay succeeds even if the destination was retired since", %{agent: agent} do
      input = draft_input(agent)
      {:ok, first} = Revenue.create_invoice_draft(input, actor: agent)

      destination =
        Ash.get!(Revenue.PaymentDestination, input.payment_destination_id, authorize?: false)

      {:ok, _} = Revenue.deactivate_payment_destination(destination, actor: agent)

      assert {:ok, %{id: id}} = Revenue.create_invoice_draft(input, actor: agent)
      assert id == first.id
    end

    test "the database refuses a second invoice with the same agent and key", %{agent: agent} do
      invoice = invoice_draft(agent)

      assert_raise Postgrex.Error, ~r/invoices_idempotency_key_per_agent_index/, fn ->
        Repo.query!(
          "INSERT INTO invoices (agent_id, idempotency_key) VALUES ($1, $2)",
          [Ecto.UUID.dump!(agent.id), invoice.idempotency_key]
        )
      end
    end
  end

  describe "an invoice only combines the agent's own records" do
    setup %{owner: owner} do
      sibling = agent(owner)
      stranger = agent(user())
      %{sibling: sibling, stranger: stranger}
    end

    test "customers of other agents, or unknown ones, are refused alike", ctx do
      for customer_id <- [
            customer(ctx.sibling).id,
            customer(ctx.stranger).id,
            Ash.UUID.generate()
          ] do
        result =
          ctx.agent
          |> draft_input(customer_id: customer_id)
          |> Revenue.create_invoice_draft(actor: ctx.agent)

        assert {:error, %Ash.Error.Invalid{errors: errors}} = result
        assert Enum.any?(errors, &(&1.message == "is not one of this agent's customers"))
      end

      assert count(Invoice) == 0
    end

    test "destinations of other agents, or unknown ones, are refused alike", ctx do
      for destination_id <- [
            payment_destination(ctx.sibling).id,
            payment_destination(ctx.stranger).id,
            Ash.UUID.generate()
          ] do
        result =
          ctx.agent
          |> draft_input(payment_destination_id: destination_id, currency: :USDC)
          |> Revenue.create_invoice_draft(actor: ctx.agent)

        assert error_fields(result) |> Enum.member?(:payment_destination_id)
      end

      assert count(Invoice) == 0
    end

    test "a retired destination cannot be chosen", %{agent: agent} do
      deactivated = payment_destination(agent)
      {:ok, _} = Revenue.deactivate_payment_destination(deactivated, actor: agent)

      superseded = payment_destination(agent)
      _replacement = payment_destination(agent, %{supersedes_id: superseded.id})

      for destination <- [deactivated, superseded] do
        assert {:error, %Ash.Error.Invalid{errors: [error | _]}} =
                 agent
                 |> draft_input(destination: destination)
                 |> Revenue.create_invoice_draft(actor: agent)

        assert error.field == :payment_destination_id
        assert error.message =~ "choose an active destination"
      end
    end

    test "the currency must be the one the destination receives", %{agent: agent} do
      usdc_on_arbitrum = payment_destination(agent, %{currency: :USDC, network: :arbitrum})

      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               agent
               |> draft_input(destination: usdc_on_arbitrum, currency: :ETH)
               |> Revenue.create_invoice_draft(actor: agent)

      assert error.field == :currency
      assert error.message == "must match the destination, which receives USDC on arbitrum"
    end
  end

  describe "amounts" do
    setup %{agent: agent} do
      %{
        eur:
          payment_destination(agent, %{
            currency: :EUR,
            network: :iban,
            address: "DE89370400440532013000"
          })
      }
    end

    test "are never rounded: more decimals than the currency allows is refused", ctx do
      for lines <- [
            [%{description: "Too precise", quantity: "1", unit_amount: "10.005"}],
            [%{description: "Rounds badly", quantity: "1.5", unit_amount: "0.05"}]
          ] do
        result =
          ctx.agent
          |> draft_input(destination: ctx.eur, lines: lines)
          |> Revenue.create_invoice_draft(actor: ctx.agent)

        assert {:error, %Ash.Error.Invalid{errors: [%{field: :lines, message: message}]}} = result
        assert message =~ "Tauros never rounds money"
      end
    end

    test "fractional quantities are fine when the amount is exact", ctx do
      lines = [%{description: "Advisory hours", quantity: "1.5", unit_amount: "120.50"}]

      assert {:ok, invoice} =
               ctx.agent
               |> draft_input(destination: ctx.eur, lines: lines)
               |> Revenue.create_invoice_draft(actor: ctx.agent)

      assert [%{total: total}] = revisions(invoice)
      assert Decimal.equal?(total, "180.75")
    end

    test "absurd magnitudes and precisions are refused at the input", ctx do
      for line <- [
            %{description: "Too many", quantity: "1000000001", unit_amount: "1"},
            %{description: "Too dear", quantity: "1", unit_amount: "1000000000000000.01"},
            %{description: "Too fine", quantity: "0.0000000000000000001", unit_amount: "1"}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 ctx.agent
                 |> draft_input(destination: ctx.eur, lines: [line])
                 |> Revenue.create_invoice_draft(actor: ctx.agent)
      end
    end

    test "quantities must be positive and the total more than zero", ctx do
      for lines <- [
            [%{description: "Negative", quantity: "-1", unit_amount: "10"}],
            [%{description: "Free", quantity: "1", unit_amount: "0"}]
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 ctx.agent
                 |> draft_input(destination: ctx.eur, lines: lines)
                 |> Revenue.create_invoice_draft(actor: ctx.agent)
      end
    end

    test "the due date cannot be in the past", %{agent: agent} do
      result =
        agent
        |> draft_input(due_date: Date.add(Date.utc_today(), -1))
        |> Revenue.create_invoice_draft(actor: agent)

      assert :due_date in error_fields(result)
    end
  end

  describe "revise_invoice" do
    test "appends a new revision with a new hash; the old one is untouched", %{agent: agent} do
      invoice = invoice_draft(agent)
      [original] = revisions(invoice)

      assert {:ok, revised} =
               Revenue.revise_invoice(
                 invoice,
                 %{
                   lines: [
                     %{description: "Implementation days", quantity: "3", unit_amount: "400"}
                   ],
                   reasoning: "Scope reduced to implementation only."
                 },
                 actor: agent
               )

      assert revised.state == :draft
      assert [^original, second] = revisions(revised)
      assert second.number == 2
      assert second.total == Decimal.new("1200")
      refute second.payload_hash == original.payload_hash
      assert second.reasoning == "Scope reduced to implementation only."
      assert {second.customer_id, second.due_date} == {original.customer_id, original.due_date}
    end

    test "revising to exactly the current payload writes nothing", %{agent: agent} do
      invoice = invoice_draft(agent)

      assert {:ok, _} =
               Revenue.revise_invoice(invoice, %{reasoning: "Nothing changed"}, actor: agent)

      assert length(revisions(invoice)) == 1
    end

    test "a revision is held to the same invariants as a draft", %{owner: owner, agent: agent} do
      invoice = invoice_draft(agent)
      foreign_customer = customer(agent(owner))

      assert {:error, %Ash.Error.Invalid{}} =
               Revenue.revise_invoice(
                 invoice,
                 %{customer_id: foreign_customer.id, reasoning: "Bill someone else"},
                 actor: agent
               )

      assert length(revisions(invoice)) == 1
    end

    test "only the proposing agent may revise", %{owner: owner, agent: agent} do
      invoice = invoice_draft(agent)

      for actor <- [agent(owner), owner, approver()] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Revenue.revise_invoice(invoice, %{reasoning: "Hijack"}, actor: actor)
      end
    end
  end

  describe "revisions are immutable" do
    test "they have no update or destroy action" do
      assert Ash.Resource.Info.actions(InvoiceRevision) |> Enum.map(& &1.type) |> Enum.sort() ==
               [:create, :read]
    end

    test "nobody can write a revision except through an Invoice action", %{
      owner: owner,
      agent: agent
    } do
      invoice = invoice_draft(agent)
      [revision] = revisions(invoice)

      attrs =
        revision
        |> Map.take([:customer_id, :payment_destination_id, :currency, :due_date, :reasoning])
        |> Map.put(:lines, [%{description: "Smuggled", quantity: "1", unit_amount: "1"}])
        |> Map.put(:invoice_id, invoice.id)

      for actor <- [agent, owner] do
        assert {:error, _} =
                 InvoiceRevision
                 |> Ash.Changeset.for_create(:create, attrs, actor: actor)
                 |> Ash.create()
      end

      assert length(revisions(invoice)) == 1
    end
  end

  describe "reading" do
    test "humans see their agents' invoices; agents see only their own", ctx do
      mine = invoice_draft(ctx.agent)
      sibling = invoice_draft(agent(ctx.owner))
      _stranger = invoice_draft(agent(user()))

      assert ids(Revenue.list_invoices!(actor: ctx.owner)) == ids([mine, sibling])
      assert ids(Revenue.list_invoices!(actor: ctx.agent)) == ids([mine])
      assert {:error, _} = Revenue.get_invoice(mine.id, actor: user())
    end

    test "revisions follow the same visibility", ctx do
      invoice = invoice_draft(ctx.agent)

      assert [_] = Ash.read!(InvoiceRevision, actor: ctx.owner)
      assert [_] = Ash.read!(InvoiceRevision, actor: ctx.agent)
      assert [] = Ash.read!(InvoiceRevision, actor: agent(ctx.owner))
      assert [] = Ash.read!(InvoiceRevision, actor: user())
      assert invoice
    end

    test "agents can read their own customers, and only theirs", %{owner: owner, agent: agent} do
      mine = customer(agent)
      _sibling = customer(agent(owner))

      assert ids(Revenue.list_customers!(actor: agent)) == ids([mine])
    end
  end

  defp ids(records), do: records |> Enum.map(& &1.id) |> Enum.sort()
end
