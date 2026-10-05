defmodule TaurosWeb.AdversarialLiveTest do
  @moduledoc """
  Hiding a button is not authorization. These tests push LiveView events by
  hand, as a modified browser could, and show that the domain refuses them.
  """
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tauros.Revenue

  setup :register_and_log_in_user

  setup %{user: operator} do
    agent = agent(operator)
    invoice = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision
    %{invoice: invoice, revision: revision}
  end

  test "an operator pushes an approve event the page never offered", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/approvals/#{ctx.invoice}")
    refute has_element?(view, "#approve-form")

    html =
      render_hook(view, "approve", %{
        "approval" => %{
          "revision_id" => ctx.revision.id,
          "payload_hash" => ctx.revision.payload_hash
        }
      })

    # Guard: Invoice policy `forbid_unless HumanApprover`.
    assert html =~ "Only an approver can decide"
    assert Revenue.get_invoice!(ctx.invoice.id, authorize?: false).state == :pending_approval
    assert [] = Ash.read!(Revenue.Approval, authorize?: false)
  end

  test "an approver submits a hash that is not the one displayed", %{conn: conn} do
    approver = approver()
    agent = agent(approver)
    invoice = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision

    {:ok, view, _html} = live(log_in_user(conn, approver), ~p"/approvals/#{invoice}")

    render_hook(view, "approve", %{
      "approval" => %{"revision_id" => revision.id, "payload_hash" => String.duplicate("0", 64)}
    })

    # Guard: Decide requires the revision's exact payload hash.
    assert Revenue.get_invoice!(invoice.id, authorize?: false).state == :pending_approval
  end

  test "a decision event without a selected proposal decides nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/approvals")
    assert render_hook(view, "approve", %{"approval" => %{}}) =~ "Select a proposal first"
  end
end
