defmodule TaurosWeb.Api.InvoicesTest do
  @moduledoc """
  The invoice routes call the same Ash actions as the UI. These tests cover
  what HTTP adds: status codes, payload shape and the authority boundary as an
  API client experiences it.
  """
  use TaurosWeb.ConnCase, async: true

  setup %{conn: conn} do
    owner = approver()
    agent = agent(owner)
    token = owner |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)

    %{
      owner: owner,
      agent: agent,
      as_agent: authorize(conn, agent.__metadata__.plaintext_api_key),
      as_human: authorize(conn, token)
    }
  end

  defp draft_payload(agent, overrides \\ %{}) do
    # Round-trip through JSON so the body is exactly what an HTTP client sends.
    %{data: %{type: "invoice", attributes: draft_input(agent, overrides)}}
    |> Jason.encode!()
    |> Jason.decode!()
  end

  describe "POST /invoices" do
    test "an agent proposes a draft; a retry is a replay", %{as_agent: as_agent, agent: agent} do
      payload = draft_payload(agent)

      created = as_agent |> post("/api/v1/invoices", payload) |> json_response(201)
      assert created["data"]["attributes"]["state"] == "draft"
      assert created["meta"]["idempotent_replay"] == false

      replayed = as_agent |> post("/api/v1/invoices", payload) |> json_response(201)
      assert replayed["data"]["id"] == created["data"]["id"]
      assert replayed["meta"]["idempotent_replay"] == true
    end

    test "the same key with another payload is 409 idempotency_conflict", %{
      as_agent: as_agent,
      agent: agent
    } do
      payload = draft_payload(agent)
      as_agent |> post("/api/v1/invoices", payload) |> json_response(201)

      conflicting = put_in(payload, ["data", "attributes", "due_date"], "2099-01-01")

      response = as_agent |> post("/api/v1/invoices", conflicting) |> json_response(409)

      assert [%{"code" => "idempotency_conflict", "source" => %{"pointer" => pointer}}] =
               response["errors"]

      assert pointer == "/data/attributes/idempotency_key"
    end

    test "a human cannot propose an invoice, even an approver", %{
      as_human: as_human,
      agent: agent
    } do
      assert as_human |> post("/api/v1/invoices", draft_payload(agent)) |> json_response(403)
    end

    test "a state sent by the client is rejected", %{as_agent: as_agent, agent: agent} do
      payload = draft_payload(agent, %{state: "approved"})
      assert as_agent |> post("/api/v1/invoices", payload) |> json_response(400)
    end
  end

  describe "GET /invoices" do
    test "includes the current revision with its payload hash", %{
      as_agent: as_agent,
      as_human: as_human,
      agent: agent
    } do
      invoice = invoice_draft(agent)

      for conn <- [as_agent, as_human] do
        response =
          conn
          |> get("/api/v1/invoices/#{invoice.id}?include=current_revision")
          |> json_response(200)

        assert [%{"type" => "invoice_revision", "attributes" => revision}] = response["included"]
        assert revision["payload_hash"] =~ ~r/^[0-9a-f]{64}$/
        assert revision["total"] == "1200"
      end
    end

    test "another human's invoices are invisible", %{conn: conn, agent: agent} do
      invoice = invoice_draft(agent)
      outsider = user() |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)
      conn = authorize(conn, outsider)

      assert conn |> get("/api/v1/invoices") |> json_response(200) |> Map.get("data") == []
      assert conn |> get("/api/v1/invoices/#{invoice.id}") |> json_response(404)
    end
  end

  describe "PATCH /invoices/:id/revise" do
    test "appends a revision", %{as_agent: as_agent, agent: agent} do
      invoice = invoice_draft(agent)

      response =
        as_agent
        |> patch("/api/v1/invoices/#{invoice.id}/revise?include=revisions", %{
          data: %{
            type: "invoice",
            id: invoice.id,
            attributes: %{due_date: "2099-12-31", reasoning: "Customer asked for more time"}
          }
        })
        |> json_response(200)

      assert response["included"] |> Enum.map(& &1["attributes"]["number"]) |> Enum.sort() ==
               [1, 2]
    end
  end

  describe "decisions" do
    setup %{agent: agent} do
      invoice = agent |> invoice_draft() |> Tauros.Revenue.submit_invoice!(actor: agent)
      revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision
      %{invoice: invoice, revision: revision}
    end

    defp decision(invoice, revision, extra \\ %{}) do
      %{
        data: %{
          type: "invoice",
          id: invoice.id,
          attributes:
            Map.merge(%{revision_id: revision.id, payload_hash: revision.payload_hash}, extra)
        }
      }
    end

    test "the owning approver approves the exact revision", ctx do
      response =
        ctx.as_human
        |> patch(
          "/api/v1/invoices/#{ctx.invoice.id}/approve?include=approvals",
          decision(ctx.invoice, ctx.revision)
        )
        |> json_response(200)

      assert response["data"]["attributes"]["state"] == "approved"
      assert [%{"attributes" => approval}] = response["included"]

      events = Ash.load!(ctx.invoice, :events, authorize?: false).events
      assert %{action: :approve, interface: :api, actor_kind: :human} = List.last(events)
      assert approval["payload_hash"] == ctx.revision.payload_hash
      assert approval["decision"] == "approved"
    end

    test "the agent's own key is refused on every authority route", ctx do
      for {route, extra} <- [
            {"approve", %{}},
            {"reject", %{reason: "x"}},
            {"request-changes", %{reason: "x"}}
          ] do
        conn =
          patch(
            ctx.as_agent,
            "/api/v1/invoices/#{ctx.invoice.id}/#{route}",
            decision(ctx.invoice, ctx.revision, extra)
          )

        assert json_response(conn, 403), "#{route} must be forbidden for agents"
      end

      assert Tauros.Revenue.get_invoice!(ctx.invoice.id, authorize?: false).state ==
               :pending_approval
    end

    test "an operator cannot approve their own agent's invoice", %{conn: conn} = ctx do
      operator = user()
      agent = agent(operator)
      invoice = agent |> invoice_draft() |> Tauros.Revenue.submit_invoice!(actor: agent)
      revision = Ash.load!(invoice, :current_revision, authorize?: false).current_revision
      token = operator |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)

      conn =
        conn
        |> authorize(token)
        |> patch("/api/v1/invoices/#{invoice.id}/approve", decision(invoice, revision))

      assert json_response(conn, 403)
      assert ctx.invoice
    end

    test "a stale revision is 409 stale_revision", ctx do
      {:ok, _} =
        Tauros.Revenue.revise_invoice(
          ctx.invoice,
          %{due_date: Date.add(Date.utc_today(), 60), reasoning: "More time"},
          actor: ctx.agent
        )

      Tauros.Revenue.submit_invoice!(ctx.invoice, actor: ctx.agent)

      response =
        ctx.as_human
        |> patch(
          "/api/v1/invoices/#{ctx.invoice.id}/approve",
          decision(ctx.invoice, ctx.revision)
        )
        |> json_response(409)

      assert [%{"code" => "stale_revision"}] = response["errors"]
    end

    test "an illegal transition is 409 invalid_transition", ctx do
      draft = invoice_draft(ctx.agent)
      revision = Ash.load!(draft, :current_revision, authorize?: false).current_revision

      response =
        ctx.as_human
        |> patch("/api/v1/invoices/#{draft.id}/approve", decision(draft, revision))
        |> json_response(409)

      assert [%{"code" => "invalid_transition"}] = response["errors"]
    end
  end
end
