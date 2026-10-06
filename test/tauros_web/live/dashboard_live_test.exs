defmodule TaurosWeb.DashboardLiveTest do
  @moduledoc "The overview: what needs attention, invoices by state, recent activity."
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tauros.Revenue

  defp pending(agent), do: agent |> invoice_draft() |> Revenue.submit_invoice!(actor: agent)

  describe "as an approver" do
    setup :register_and_log_in_approver

    test "leads with the proposals waiting for a decision, and links to them", %{
      conn: conn,
      user: user
    } do
      agent = agent(user, name: "Billing agent")
      first = pending(agent)
      _second = pending(agent)
      _foreign = pending(agent(user()))

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-count", "2")
      assert has_element?(view, "#attention-count", "waiting for your decision")
      assert has_element?(view, "#review-oldest[href='/invoices/#{first.id}/review']")
      assert has_element?(view, "#pending-#{first.id}", "from Billing agent")
      assert has_element?(view, "#nav-needs-review-count", "2")
    end

    test "counts invoices by state, including drafts sent back", %{conn: conn, user: user} do
      agent = agent(user)
      sent_back = pending(agent)
      revision = Ash.load!(sent_back, :current_revision, authorize?: false).current_revision

      {:ok, _} =
        Revenue.request_invoice_changes(
          sent_back,
          %{revision_id: revision.id, payload_hash: revision.payload_hash, reason: "Fix it"},
          actor: user
        )

      _draft = invoice_draft(agent)
      _pending = pending(agent)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#stat-review", "1")
      assert has_element?(view, "#stat-draft", "2")
      assert has_element?(view, "#stat-draft", "1 sent back")
      assert has_element?(view, "#stat-review[href='/invoices?status=review']")
    end

    test "shows recent activity with named actors", %{conn: conn, user: user} do
      agent = agent(user, name: "Billing agent")
      invoice = invoice_draft(agent, customer: customer(agent, name: "Acme Inc"))

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#activity", "Billing agent proposed the invoice for Acme Inc")
      assert has_element?(view, "#activity a[href='/invoices/#{invoice.id}']")
    end

    test "is calm and explanatory when nothing exists yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-clear", "Nothing needs your review")
      assert has_element?(view, "#attention", "REST API or MCP")
      assert has_element?(view, "#activity-empty")
    end
  end

  describe "as an operator" do
    setup :register_and_log_in_user

    test "sees waiting work but no call to decide", %{conn: conn, user: user} do
      pending(agent(user))

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-count", "waiting for an approver")
      refute has_element?(view, "#review-oldest")
    end

    test "counts setup records the human owns", %{conn: conn, user: user} do
      agent = agent(user)
      customer(agent)
      customer(agent)
      payment_destination(agent)
      agent(user()) |> customer()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#setup", "1 agent")
      assert has_element?(view, "#setup", "2 customers")
      assert has_element?(view, "#setup", "1 active payment destination")
    end
  end

  describe "navigation" do
    setup :register_and_log_in_approver

    test "is organized around the revenue workflow, with review under invoices", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for {id, path} <- [
            {"overview", "/"},
            {"needs-review", "/invoices/review"},
            {"invoices", "/invoices"},
            {"customers", "/customers"},
            {"destinations", "/destinations"},
            {"agents", "/agents"},
            {"invite", "/invite"}
          ] do
        assert has_element?(view, "#nav-#{id}[href='#{path}']")
        assert has_element?(view, "#mobile-menu a[href='#{path}']")
      end

      assert has_element?(view, "#nav-overview[aria-current='page']")
      refute has_element?(view, "a[href='/approvals']")
      assert has_element?(view, "#mobile-menu", "Revenue")
      assert has_element?(view, "#mobile-menu a[href='/sign-out'][data-method='delete']")
      assert has_element?(view, "#mobile-menu-button[aria-controls='mobile-menu']")
    end

    test "marks the current section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/invoices/review")
      assert has_element?(view, "#nav-needs-review[aria-current='page']")
      refute has_element?(view, "#nav-invoices[aria-current='page']")
    end
  end

  test "operators get no Invite link" do
    conn = log_in_user(build_conn(), user())
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#nav-invite")
  end

  test "redirects anonymous visitors to sign in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/")
  end
end
