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
end
