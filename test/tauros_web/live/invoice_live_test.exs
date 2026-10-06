defmodule TaurosWeb.InvoiceLiveTest do
  @moduledoc "The invoice list and the invoice page: state, next step, contextual links."
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tauros.Revenue

  setup :register_and_log_in_approver

  defp pending(agent), do: agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)

  defp decide(invoice, fun, user, extra \\ %{}) do
    revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision

    {:ok, _} =
      fun.(
        invoice,
        Map.merge(%{revision_id: revision.id, payload_hash: revision.payload_hash}, extra),
        actor: user
      )
  end

  describe "list" do
    test "shows every state, and a pending invoice links to its review", %{conn: conn, user: user} do
      agent = agent(user, name: "Billing agent")
      draft = invoice_draft(agent)
      waiting = pending(agent)
      foreign = invoice_draft(agent(user()))

      {:ok, view, _html} = live(conn, ~p"/invoices")

      assert has_element?(view, "#invoices-#{draft.id}", "Draft")
      assert has_element?(view, "#invoices-#{draft.id}", "from Billing agent")
      assert has_element?(view, "#invoices-#{waiting.id}", "Pending approval")
      assert has_element?(view, "#invoices-#{waiting.id}", "Needs your review")
      assert has_element?(view, "#review-#{waiting.id}[href='/invoices/#{waiting.id}/review']")
      refute has_element?(view, "#review-#{draft.id}")
      refute has_element?(view, "#invoices-#{foreign.id}")
    end

    test "filters by where invoices are in their lifecycle", %{conn: conn, user: user} do
      agent = agent(user)
      draft = invoice_draft(agent)
      waiting = pending(agent)
      rejected = pending(agent)
      decide(rejected, &Revenue.reject_invoice/3, user, %{reason: "No"})

      {:ok, view, _html} = live(conn, ~p"/invoices?status=review")
      assert has_element?(view, "#invoices-#{waiting.id}")
      refute has_element?(view, "#invoices-#{draft.id}")
      assert has_element?(view, "#filter-review[aria-current='page']", "1")

      {:ok, view, _html} = live(conn, ~p"/invoices?status=closed")
      assert has_element?(view, "#invoices-#{rejected.id}", "Rejected")
      refute has_element?(view, "#invoices-#{waiting.id}")

      {:ok, view, _html} = live(conn, ~p"/invoices?status=approved")
      assert has_element?(view, "#empty-state", "No invoices in this state")
    end

    test "a sent-back draft says so", %{conn: conn, user: user} do
      invoice = user |> agent() |> pending()
      decide(invoice, &Revenue.request_invoice_changes/3, user, %{reason: "Fix the date"})

      {:ok, view, _html} = live(conn, ~p"/invoices")
      assert has_element?(view, "#invoices-#{invoice.id}", "Changes requested")
      assert has_element?(view, "#invoices-#{invoice.id}", "Agent to revise")
    end
  end

  describe "invoice page" do
    test "a pending invoice offers the review to an approver", %{conn: conn, user: user} do
      invoice = user |> agent(name: "Billing agent") |> pending()

      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")

      assert has_element?(view, "#invoice-state", "Pending approval")
      assert has_element?(view, "#lifecycle [aria-current='step']", "Pending approval")
      assert has_element?(view, "#next-step", "This proposal needs your decision")
      assert has_element?(view, "#review-link[href='/invoices/#{invoice.id}/review']")
    end

    test "an operator sees who has authority, without a review action", %{user: user} do
      operator = user()
      invoice = operator |> agent() |> pending()
      conn = log_in_user(build_conn(), operator)

      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")

      assert has_element?(view, "#next-step", "Waiting for a human approver")
      refute has_element?(view, "#review-link")
      assert user
    end

    test "an approved invoice shows its decision and history", %{conn: conn, user: user} do
      invoice = user |> agent(name: "Billing agent") |> pending()
      decide(invoice, &Revenue.approve_invoice/3, user, %{reason: "Matches the SOW"})

      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")

      assert has_element?(view, "#invoice-state", "Approved")
      assert has_element?(view, "#lifecycle [aria-current='step']", "Approved")
      assert has_element?(view, "#next-step", "Nothing has been issued or paid yet")
      assert has_element?(view, "#decisions", "Approved")
      assert has_element?(view, "#decisions", "Matches the SOW")
      assert has_element?(view, "#invoice-history", "Billing agent proposed this invoice")
      assert has_element?(view, "#invoice-history", "You approved this invoice")
      refute has_element?(view, "#review-link")
    end

    test "a rejected invoice is closed", %{conn: conn, user: user} do
      invoice = user |> agent() |> pending()
      decide(invoice, &Revenue.reject_invoice/3, user, %{reason: "Duplicate"})

      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice}")

      assert has_element?(view, "#lifecycle [aria-current='step']", "Rejected")
      assert has_element?(view, "#next-step", "This invoice is closed")
      assert has_element?(view, "#next-step", "Duplicate")
    end

    test "points to the next proposal to review", %{conn: conn, user: user} do
      agent = agent(user)
      decided = pending(agent)
      _other = pending(agent)
      decide(decided, &Revenue.approve_invoice/3, user)

      {:ok, view, _html} = live(conn, ~p"/invoices/#{decided}")

      assert has_element?(
               view,
               "#next-review[href='/invoices/review']",
               "1 proposal needs review"
             )
    end
  end
end
