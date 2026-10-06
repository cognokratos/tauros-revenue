defmodule TaurosWeb.Api.ResourcesTest do
  @moduledoc """
  Contract tests for the JSON:API. The same Ash actions and policies serve the
  LiveView UI, so these tests focus on what is specific to HTTP: routes,
  payload shape, credentials and status codes.
  """
  use TaurosWeb.ConnCase, async: true

  @eth "0x1234567890123456789012345678901234567890"

  setup %{conn: conn} do
    user = user()
    token = user |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)
    %{user: user, human: authorize(conn, token)}
  end

  defp payload(type, attributes), do: %{data: %{type: type, attributes: attributes}}

  defp payload(type, id, attributes),
    do: %{data: %{type: type, id: id, attributes: attributes}}

  describe "agents" do
    test "POST returns the API key once in meta and never stores it", %{human: human, user: user} do
      response =
        human
        |> post("/api/v1/agents", payload("agent", %{name: "Billing bot"}))
        |> json_response(201)

      assert %{"data" => %{"id" => id, "attributes" => attrs}, "meta" => %{"api_key" => key}} =
               response

      assert attrs["name"] == "Billing bot"
      assert "tauros_" <> _ = key
      refute Map.has_key?(attrs, "api_key")
      assert Tauros.Accounts.get_agent!(id, actor: user).user_id == user.id

      shown = human |> get("/api/v1/agents/#{id}") |> json_response(200)
      refute get_in(shown, ["meta", "api_key"])
    end

    test "POST without a name is a 400 with a JSON:API error", %{human: human} do
      response = human |> post("/api/v1/agents", payload("agent", %{})) |> json_response(400)
      assert [%{"source" => %{"pointer" => "/data/attributes/name"}}] = response["errors"]
    end

    test "rotating the key returns a new one", %{human: human, user: user} do
      agent = agent(user)

      response =
        human
        |> patch("/api/v1/agents/#{agent.id}/rotate-api-key", payload("agent", agent.id, %{}))
        |> json_response(200)

      assert response["meta"]["api_key"] != agent.__metadata__.plaintext_api_key
    end

    test "agents cannot register agents", %{conn: conn, user: user} do
      key = agent(user).__metadata__.plaintext_api_key

      conn =
        conn |> authorize(key) |> post("/api/v1/agents", payload("agent", %{name: "Child"}))

      assert json_response(conn, 403)
    end
  end

  describe "customers" do
    setup %{user: user}, do: %{agent: agent(user)}

    test "full lifecycle for the owner", %{human: human, agent: agent} do
      created =
        human
        |> post(
          "/api/v1/customers",
          payload("customer", %{name: "Acme Inc", email: "contact@acme.com", agent_id: agent.id})
        )
        |> json_response(201)

      id = created["data"]["id"]
      assert created["data"]["attributes"]["agent_id"] == agent.id

      assert [%{"id" => ^id}] =
               human |> get("/api/v1/customers") |> json_response(200) |> Map.get("data")

      assert %{"data" => %{"attributes" => %{"name" => "Acme Inc"}}} =
               human |> get("/api/v1/customers/#{id}") |> json_response(200)

      assert %{"data" => %{"attributes" => %{"name" => "Updated Name"}}} =
               human
               |> patch(
                 "/api/v1/customers/#{id}",
                 payload("customer", id, %{name: "Updated Name"})
               )
               |> json_response(200)

      assert human |> delete("/api/v1/customers/#{id}") |> response(200)
      assert human |> get("/api/v1/customers/#{id}") |> json_response(404)
    end

    test "missing fields are reported per attribute", %{human: human} do
      response =
        human
        |> post("/api/v1/customers", payload("customer", %{name: "Acme"}))
        |> json_response(400)

      pointers = response["errors"] |> Enum.map(& &1["source"]["pointer"]) |> Enum.sort()
      assert pointers == ["/data/attributes/agent_id", "/data/attributes/email"]
    end

    test "another human's agent cannot be used", %{conn: conn, agent: agent} do
      outsider = user() |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)

      conn =
        conn
        |> authorize(outsider)
        |> post(
          "/api/v1/customers",
          payload("customer", %{name: "Acme", email: "a@acme.com", agent_id: agent.id})
        )

      assert json_response(conn, 403)
    end

    test "ownership cannot be reassigned", %{human: human, user: user, agent: agent} do
      customer = customer(agent)
      other_agent = agent(user)

      conn =
        patch(
          human,
          "/api/v1/customers/#{customer.id}",
          payload("customer", customer.id, %{name: "New Name", agent_id: other_agent.id})
        )

      assert json_response(conn, 400)
      assert Tauros.Revenue.get_customer!(customer.id, actor: user).agent_id == agent.id
    end

    test "other humans' customers are invisible", %{conn: conn, agent: agent} do
      customer = customer(agent)
      outsider = user() |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)
      conn = authorize(conn, outsider)

      assert conn |> get("/api/v1/customers") |> json_response(200) |> Map.get("data") == []
      assert conn |> get("/api/v1/customers/#{customer.id}") |> json_response(404)
    end
  end

  describe "payment destinations" do
    setup %{conn: conn, user: user} do
      agent = agent(user)
      %{agent: agent, as_agent: authorize(conn, agent.__metadata__.plaintext_api_key)}
    end

    defp destination_payload(overrides \\ %{}) do
      payload(
        "payment_destination",
        Map.merge(
          %{label: "Treasury", currency: "USDC", network: "arbitrum", address: @eth},
          overrides
        )
      )
    end

    test "an agent registers a destination for itself", %{as_agent: as_agent, agent: agent} do
      response =
        as_agent
        |> post("/api/v1/payment-destinations", destination_payload())
        |> json_response(201)

      assert %{
               "label" => "Treasury",
               "currency" => "USDC",
               "network" => "arbitrum",
               "address" => @eth,
               "agent_id" => agent_id
             } = response["data"]["attributes"]

      assert agent_id == agent.id
    end

    test "invalid addresses are rejected", %{as_agent: as_agent} do
      response =
        as_agent
        |> post(
          "/api/v1/payment-destinations",
          destination_payload(%{currency: "EUR", network: "iban"})
        )
        |> json_response(400)

      assert [%{"source" => %{"pointer" => "/data/attributes/address"}}] = response["errors"]
    end

    test "a network that cannot carry the currency is rejected", %{as_agent: as_agent} do
      response =
        as_agent
        |> post("/api/v1/payment-destinations", destination_payload(%{currency: "BTC"}))
        |> json_response(400)

      assert [%{"source" => %{"pointer" => "/data/attributes/network"}}] = response["errors"]
    end

    test "an agent deactivates its own destination", %{as_agent: as_agent, agent: agent} do
      destination = payment_destination(agent)

      response =
        as_agent
        |> patch(
          "/api/v1/payment-destinations/#{destination.id}/deactivate",
          payload("payment_destination", destination.id, %{})
        )
        |> json_response(200)

      assert response["data"]["attributes"]["state"] == "deactivated"
    end

    test "state cannot be written through the API", %{as_agent: as_agent, agent: agent} do
      destination = payment_destination(agent)

      conn =
        patch(
          as_agent,
          "/api/v1/payment-destinations/#{destination.id}/deactivate",
          payload("payment_destination", destination.id, %{state: "active", address: @eth})
        )

      assert json_response(conn, 400)

      conn = post(as_agent, "/api/v1/payment-destinations", destination_payload(%{state: "x"}))
      assert json_response(conn, 400)
    end

    test "humans can list but not register destinations", %{human: human, agent: agent} do
      destination = payment_destination(agent)

      assert [%{"id" => id}] =
               human
               |> get("/api/v1/payment-destinations")
               |> json_response(200)
               |> Map.get("data")

      assert id == destination.id

      conn = post(human, "/api/v1/payment-destinations", destination_payload())
      assert json_response(conn, 403)
    end
  end
end
