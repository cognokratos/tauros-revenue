defmodule TaurosWeb.InvoiceLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tauros.Revenue

  setup :register_and_log_in_approver

  test "lists the human's invoices in every state", %{conn: conn, user: user} do
    agent = agent(user)
    draft = invoice_draft(agent)
    pending = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    foreign = invoice_draft(agent(user()))

    {:ok, view, _html} = live(conn, ~p"/invoices")

    assert has_element?(view, "#invoices-#{draft.id}", "draft")
    assert has_element?(view, "#invoices-#{pending.id}", "pending approval")
    refute has_element?(view, "#invoices-#{foreign.id}")
  end

  test "an invoice page shows its decisions and history", %{conn: conn, user: user} do
    agent = agent(user)
    invoice = agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)
    revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision

    {:ok, _} =
      Revenue.approve_invoice(
        invoice,
        %{
          revision_id: revision.id,
          payload_hash: revision.payload_hash,
          reason: "Matches the SOW"
        },
        actor: user
      )

    {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")

    assert has_element?(view, "#invoice-state", "approved")
    assert has_element?(view, "#decisions", "approved")
    assert has_element?(view, "#decisions", "Matches the SOW")
    assert has_element?(view, "#invoice-history", "approve")
    refute has_element?(view, "#review-link")
  end

  test "the dashboard points to waiting proposals", %{conn: conn, user: user} do
    agent = agent(user)
    agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#awaiting-approval", "1 proposal is waiting")
  end
end
