defmodule TaurosWeb.ApprovalLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tauros.Revenue

  defp pending(agent, attrs \\ %{}) do
    agent |> invoice_draft(attrs) |> Revenue.submit_invoice!(actor: agent)
  end

  defp current(invoice),
    do: Ash.load!(invoice, :current_revision, authorize?: false).current_revision

  defp reload(invoice), do: Ash.get!(Revenue.Invoice, invoice.id, authorize?: false)

  describe "as an approver" do
    setup :register_and_log_in_approver

    setup %{user: user} do
      agent = agent(user, name: "Billing agent")
      %{agent: agent, invoice: pending(agent, customer: customer(agent, name: "Acme Inc"))}
    end

    test "lists only pending proposals of the human's own agents", ctx do
      draft = invoice_draft(ctx.agent)
      foreign = pending(agent(user()))

      {:ok, view, _html} = live(ctx.conn, ~p"/approvals")

      assert has_element?(view, "#pending-#{ctx.invoice.id}", "Acme Inc")
      assert has_element?(view, "#pending-#{ctx.invoice.id}", "1200.00 USDC")
      refute has_element?(view, "#pending-#{draft.id}")
      refute has_element?(view, "#pending-#{foreign.id}")
    end

    test "shows the exact financial intent of the selected proposal", ctx do
      revision = current(ctx.invoice)
      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      assert has_element?(view, "#intent-summary", "Acme Inc")
      assert has_element?(view, "#intent-summary", "1200.00 USDC")
      assert has_element?(view, "#intent-summary", "Ethereum mainnet")
      assert has_element?(view, "#agent-reasoning", "Monthly retainer")
      assert has_element?(view, "#invoice-total", "1200.00 USDC")
      assert has_element?(view, "#payload-hash", revision.payload_hash)
      assert has_element?(view, "#revision-number", "1 of 1")

      assert has_element?(
               view,
               "#approve-form input[name='approval[payload_hash]'][value='#{revision.payload_hash}']"
             )

      assert has_element?(view, "#invoice-history", "create draft")
    end

    test "viewing a proposal never decides anything", ctx do
      {:ok, _view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      assert reload(ctx.invoice).state == :pending_approval
      assert [] = Ash.read!(Revenue.Approval, authorize?: false)
    end

    test "approving authorizes the displayed revision, via the UI", ctx do
      revision = current(ctx.invoice)
      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      view |> form("#approve-form") |> render_submit()
      assert_patch(view, ~p"/approvals")

      assert reload(ctx.invoice).state == :approved
      assert [approval] = Ash.read!(Revenue.Approval, authorize?: false)
      assert {approval.revision_id, approval.payload_hash} == {revision.id, revision.payload_hash}

      events = Ash.load!(ctx.invoice, :events, authorize?: false).events
      assert %{action: :approve, interface: :ui} = List.last(events)
      assert has_element?(view, "#empty-state")
    end

    test "sending back requires a reason and then records it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      view
      |> form("#decline-form", decision: %{reason: ""})
      |> render_submit(%{"outcome" => "request_changes"})

      assert reload(ctx.invoice).state == :pending_approval

      view
      |> form("#decline-form", decision: %{reason: "Use the Arbitrum destination"})
      |> render_submit(%{"outcome" => "request_changes"})

      assert reload(ctx.invoice).state == :draft

      assert [%{decision: :changes_requested, reason: "Use the Arbitrum destination"}] =
               Ash.read!(Revenue.Approval, authorize?: false)
    end

    test "rejecting is a separate, explicit choice", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      view
      |> form("#decline-form", decision: %{reason: "Not our customer"})
      |> render_submit(%{"outcome" => "reject"})

      assert reload(ctx.invoice).state == :rejected
    end

    test "a proposal that changed while on screen is not approved", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      # The agent revises and resubmits while the human is reading revision 1.
      {:ok, _} =
        Revenue.revise_invoice(
          ctx.invoice,
          %{due_date: Date.add(Date.utc_today(), 5), reasoning: "Shorter terms"},
          actor: ctx.agent
        )

      Revenue.submit_invoice!(ctx.invoice, actor: ctx.agent)

      html = view |> form("#approve-form") |> render_submit()

      assert html =~ "changed while you were reviewing it"
      assert reload(ctx.invoice).state == :pending_approval
      assert [] = Ash.read!(Revenue.Approval, authorize?: false)
      assert has_element?(view, "#revision-number", "2 of 2")
    end

    test "a retired destination is flagged and cannot be approved", ctx do
      destination =
        Ash.get!(Revenue.PaymentDestination, current(ctx.invoice).payment_destination_id,
          authorize?: false
        )

      {:ok, _} = Revenue.deactivate_payment_destination(destination, actor: ctx.agent)

      {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")

      assert has_element?(view, "#destination-warning")
      refute has_element?(view, "#approve-form")
      assert has_element?(view, "#decline-form")
    end

    test "shows an empty state", %{conn: conn, agent: agent, invoice: invoice} do
      {:ok, _} = Revenue.withdraw_invoice(invoice, actor: agent)
      {:ok, view, _html} = live(conn, ~p"/approvals")
      assert has_element?(view, "#empty-state", "Nothing is waiting")
    end
  end

  describe "as an operator" do
    setup :register_and_log_in_user

    test "can review but has no decision controls", %{conn: conn, user: user} do
      agent = agent(user)
      invoice = pending(agent)

      {:ok, view, _html} = live(conn, ~p"/approvals/#{invoice}")

      assert has_element?(view, "#financial-intent")
      assert has_element?(view, "#review-only", "Only an approver can decide")
      refute has_element?(view, "#decision-panel")
    end
  end

  test "requires authentication" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/approvals")
  end
end
