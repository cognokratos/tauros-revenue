defmodule TaurosWeb.Mcp.ToolsTest do
  @moduledoc """
  The reviewed MCP tools, exercised over the real HTTP endpoint as an AI
  client would: discovery, reads bounded to the agent, the whole proposal flow
  up to the human boundary, retries, audit, and errors a model can act on.
  """
  use TaurosWeb.ConnCase, async: true

  import TaurosWeb.McpClient, only: [call: 3, call: 2, as_json: 1]

  alias Tauros.Revenue

  setup do
    owner = approver()
    agent = agent(owner)
    customer = customer(agent, name: "Acme Inc")

    destination =
      payment_destination(agent, %{label: "Treasury", currency: :USDC, network: :arbitrum})

    %{
      owner: owner,
      agent: agent,
      key: agent.__metadata__.plaintext_api_key,
      customer: customer,
      destination: destination
    }
  end

  defp draft(ctx, overrides \\ %{}),
    do: %{
      "input" =>
        as_json(
          draft_input(
            ctx.agent,
            Map.merge(%{customer: ctx.customer, destination: ctx.destination}, overrides)
          )
        )
    }

  defp results({:ok, %{"results" => results}}), do: results
  defp results({:ok, results}) when is_list(results), do: results

  describe "read tools" do
    test "list_customers returns id and name only: no email, no owner", ctx do
      assert [customer] = results(call(ctx.key, "list_customers"))
      assert customer == %{"id" => ctx.customer.id, "name" => "Acme Inc"}
    end

    test "list_payment_destinations returns only usable (active) destinations", ctx do
      retired = payment_destination(ctx.agent, %{label: "Old"})
      {:ok, _} = Revenue.deactivate_payment_destination(retired, actor: ctx.agent)

      assert [destination] = results(call(ctx.key, "list_payment_destinations"))

      assert destination == %{
               "id" => ctx.destination.id,
               "label" => "Treasury",
               "currency" => "USDC",
               "network" => "arbitrum",
               "address" => ctx.destination.address,
               "state" => "active"
             }
    end

    test "list_invoices and get_invoice return a bounded summary and the current revision", ctx do
      invoice = invoice_draft(ctx.agent, customer: ctx.customer, destination: ctx.destination)

      assert [summary] = results(call(ctx.key, "list_invoices"))
      assert %{"id" => id, "state" => "draft", "current_revision" => revision} = summary
      assert id == invoice.id
      assert revision["total"] == "1200"

      assert Enum.sort(Map.keys(revision)) ==
               ~w(currency customer_id due_date id invoice_id number total)

      assert {:ok, full} = call(ctx.key, "get_invoice", %{"id" => invoice.id})
      current = full["current_revision"]
      assert current["customer"] == %{"id" => ctx.customer.id, "name" => "Acme Inc"}
      assert current["payment_destination"]["network"] == "arbitrum"
      assert current["payload_hash"] =~ ~r/^[0-9a-f]{64}$/
      assert [%{"quantity" => "1", "unit_amount" => "400"} | _] = current["lines"]
      assert current["approval"] == nil
      refute Map.has_key?(current, "canonical_payload")
      refute Map.has_key?(full, "events")
    end

    test "an agent never sees another agent's records, even its sibling's", ctx do
      sibling = agent(ctx.owner)
      theirs = invoice_draft(sibling)
      _their_customer = customer(sibling)
      _their_destination = payment_destination(sibling)

      assert [_] = results(call(ctx.key, "list_customers"))
      assert [_] = results(call(ctx.key, "list_payment_destinations"))
      assert [] = results(call(ctx.key, "list_invoices"))

      # A foreign invoice and a nonexistent one look the same.
      assert call(ctx.key, "get_invoice", %{"id" => theirs.id}) ==
               call(ctx.key, "get_invoice", %{"id" => Ash.UUID.generate()})
    end
  end

  describe "the proposal flow ends at the human boundary" do
    test "read, draft, inspect, revise and submit: then a human must decide", ctx do
      [%{"id" => customer_id}] = results(call(ctx.key, "list_customers"))

      [%{"id" => destination_id, "currency" => currency}] =
        results(call(ctx.key, "list_payment_destinations"))

      arguments = %{
        "input" => %{
          "idempotency_key" => "acme-2026-10",
          "customer_id" => customer_id,
          "payment_destination_id" => destination_id,
          "currency" => currency,
          "due_date" => Date.utc_today() |> Date.add(30) |> Date.to_iso8601(),
          "lines" => [
            %{"description" => "Retainer", "quantity" => "1", "unit_amount" => "1000.50"}
          ],
          "reasoning" => "Retainer per the signed agreement."
        }
      }

      assert {:ok, %{"id" => id, "state" => "draft"}} =
               call(ctx.key, "create_invoice_draft", arguments)

      assert {:ok, %{"current_revision" => %{"number" => 1, "total" => "1000.50"}}} =
               call(ctx.key, "get_invoice", %{"id" => id})

      assert {:ok, %{"state" => "draft"}} =
               call(ctx.key, "revise_invoice", %{
                 "id" => id,
                 "input" => %{
                   "lines" => [
                     %{"description" => "Retainer", "quantity" => "1", "unit_amount" => "1200.00"}
                   ],
                   "reasoning" => "The agreement says 1,200."
                 }
               })

      assert {:ok, %{"state" => "pending_approval"}} =
               call(ctx.key, "submit_invoice", %{"id" => id})

      # The agent stops here. The proposal is in the human's approval queue.
      assert [%{id: ^id}] = Revenue.list_invoices_awaiting_approval!(actor: ctx.owner)

      revision =
        Revenue.get_invoice!(id, actor: ctx.owner, load: :current_revision).current_revision

      assert {revision.number, Decimal.equal?(revision.total, 1200)} == {2, true}
    end
  end

  describe "withdraw_invoice" do
    test "withdraws the agent's undecided proposal", ctx do
      {:ok, %{"id" => id}} = call(ctx.key, "create_invoice_draft", draft(ctx))
      {:ok, _} = call(ctx.key, "submit_invoice", %{"id" => id})

      assert {:ok, %{"state" => "cancelled"}} = call(ctx.key, "withdraw_invoice", %{"id" => id})
    end

    test "cannot undo a human approval", ctx do
      {:ok, %{"id" => id}} = call(ctx.key, "create_invoice_draft", draft(ctx))
      {:ok, _} = call(ctx.key, "submit_invoice", %{"id" => id})
      invoice = Revenue.get_invoice!(id, actor: ctx.owner, load: :current_revision)

      {:ok, _} =
        Revenue.approve_invoice(
          invoice,
          %{
            revision_id: invoice.current_revision.id,
            payload_hash: invoice.current_revision.payload_hash
          },
          actor: ctx.owner
        )

      assert {:tool_error,
              "withdraw is not allowed while the invoice is approved (invalid_transition)"} =
               call(ctx.key, "withdraw_invoice", %{"id" => id})

      assert {:tool_error, message} =
               call(ctx.key, "revise_invoice", %{"id" => id, "input" => %{"reasoning" => "edit"}})

      assert message =~ "invalid_transition"
      assert Revenue.get_invoice!(id, actor: ctx.owner).state == :approved
    end
  end

  describe "retries" do
    test "same key and payload return the original; a different payload is a conflict", ctx do
      arguments = draft(ctx)

      assert {:ok, %{"id" => id}} = call(ctx.key, "create_invoice_draft", arguments)
      assert {:ok, %{"id" => ^id}} = call(ctx.key, "create_invoice_draft", arguments)

      changed =
        put_in(arguments, ["input", "lines"], [
          %{"description" => "x", "quantity" => "1", "unit_amount" => "1"}
        ])

      assert {:tool_error, message} = call(ctx.key, "create_invoice_draft", changed)

      assert message =~
               "idempotency_key: was already used by this agent for a different financial payload"

      assert message =~ "(idempotency_conflict)"
      assert Ash.count!(Revenue.Invoice, authorize?: false) == 1
    end

    test "submitting twice is harmless", ctx do
      {:ok, %{"id" => id}} = call(ctx.key, "create_invoice_draft", draft(ctx))

      assert {:ok, %{"state" => "pending_approval"}} =
               call(ctx.key, "submit_invoice", %{"id" => id})

      assert {:ok, %{"state" => "pending_approval"}} =
               call(ctx.key, "submit_invoice", %{"id" => id})
    end
  end

  describe "errors tell the model what to fix, without leaking other tenants" do
    setup do
      stranger = agent(user())
      %{stranger: stranger}
    end

    defp refused(ctx, overrides) do
      assert {:tool_error, message} = call(ctx.key, "create_invoice_draft", draft(ctx, overrides))
      refute message =~ "unexpected error"
      refute message =~ ~r/\*\*|stacktrace|Elixir\./
      message
    end

    test "unknown and foreign customers get the same message", ctx do
      foreign = refused(ctx, %{customer_id: customer(ctx.stranger).id})
      unknown = refused(ctx, %{customer_id: Ash.UUID.generate()})

      assert foreign == unknown
      assert foreign =~ "customer_id: is not one of this agent's customers"
    end

    test "unknown and foreign destinations get the same message", ctx do
      foreign = refused(ctx, %{payment_destination_id: payment_destination(ctx.stranger).id})
      unknown = refused(ctx, %{payment_destination_id: Ash.UUID.generate()})

      assert foreign == unknown
      assert foreign =~ "payment_destination_id: is not one of this agent's payment destinations"
    end

    test "an inactive destination", ctx do
      {:ok, _} = Revenue.deactivate_payment_destination(ctx.destination, actor: ctx.agent)

      assert refused(ctx, %{}) =~
               "payment_destination_id: is deactivated; choose an active destination"
    end

    test "a currency the destination does not receive", ctx do
      assert refused(ctx, %{currency: :ETH}) =~
               "currency: must match the destination, which receives USDC on arbitrum"
    end

    test "a past due date", ctx do
      assert refused(ctx, %{due_date: Date.add(Date.utc_today(), -1)}) =~
               "due_date: must not be in the past"
    end

    test "more decimals than the currency allows", ctx do
      lines = [%{description: "x", quantity: "1", unit_amount: "1.0000001"}]

      assert refused(ctx, %{lines: lines}) =~
               "has more decimal places than USDC allows (6); Tauros never rounds money"
    end

    test "amounts sent as JSON numbers instead of decimal strings", ctx do
      arguments =
        put_in(draft(ctx), ["input", "lines"], [
          %{"description" => "x", "quantity" => 1, "unit_amount" => 0.1}
        ])

      assert {:tool_error, message} = call(ctx.key, "create_invoice_draft", arguments)
      assert message =~ "input.lines.0.unit_amount: send amounts as decimal strings"
      assert Ash.count!(Revenue.Invoice, authorize?: false) == 0
    end

    test "an illegal transition", ctx do
      {:ok, %{"id" => id}} = call(ctx.key, "create_invoice_draft", draft(ctx))
      {:ok, _} = call(ctx.key, "withdraw_invoice", %{"id" => id})

      assert {:tool_error,
              "submit_for_approval is not allowed while the invoice is cancelled (invalid_transition)"} =
               call(ctx.key, "submit_invoice", %{"id" => id})
    end
  end
end
