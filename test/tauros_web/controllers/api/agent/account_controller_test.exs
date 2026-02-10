defmodule TaurosWeb.Api.Agent.AccountControllerTest do
  use TaurosWeb.ConnCase

  import Tauros.AgentsFixtures

  describe "POST /api/v1/accounts" do
    test "creates account with valid API key and required fields", %{conn: conn} do
      agent = agent_fixture()
      api_key = agent.api_key

      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> post("/api/v1/accounts", %{
          wallet_name: "My Wallet",
          public_address: "0x1234567890123456789012345678901234567890",
          currency: "USD"
        })

      assert %{
               "data" => %{
                 "id" => account_id,
                 "wallet_name" => "My Wallet",
                 "public_address" => "0x1234567890123456789012345678901234567890",
                 "currency" => "USD",
                 "agent_id" => agent_id
               }
             } = json_response(conn, 201)

      assert agent_id == agent.id
      assert account_id != nil
    end

    test "returns 422 when wallet_name is missing", %{conn: conn} do
      agent = agent_fixture()
      api_key = agent.api_key

      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> post("/api/v1/accounts", %{
          public_address: "0x1234567890123456789012345678901234567890",
          currency: "USD"
        })

      assert response(conn, 422)
      assert %{"error" => %{"code" => code}} = json_response(conn, 422)
      assert code == "validation_error"
    end

    test "returns 422 when public_address is missing", %{conn: conn} do
      agent = agent_fixture()
      api_key = agent.api_key

      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> post("/api/v1/accounts", %{
          wallet_name: "My Wallet",
          currency: "USD"
        })

      assert response(conn, 422)
      assert %{"error" => %{"code" => code}} = json_response(conn, 422)
      assert code == "validation_error"
    end

    test "returns 422 when currency is missing", %{conn: conn} do
      agent = agent_fixture()
      api_key = agent.api_key

      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> post("/api/v1/accounts", %{
          wallet_name: "My Wallet",
          public_address: "0x1234567890123456789012345678901234567890"
        })

      assert response(conn, 422)
      assert %{"error" => %{"code" => code}} = json_response(conn, 422)
      assert code == "validation_error"
    end

    test "returns 401 with missing X-API-KEY header", %{conn: conn} do
      conn =
        post(conn, "/api/v1/accounts", %{
          wallet_name: "My Wallet",
          public_address: "0x1234567890123456789012345678901234567890",
          currency: "USD"
        })

      assert response(conn, 401)
      assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
    end

    test "returns 401 with invalid X-API-KEY", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "invalid_key_12345")
        |> post("/api/v1/accounts", %{
          wallet_name: "My Wallet",
          public_address: "0x1234567890123456789012345678901234567890",
          currency: "USD"
        })

      assert response(conn, 401)
      assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
    end

    test "account is scoped to the agent", %{conn: conn} do
      agent1 = agent_fixture()
      agent2 = agent_fixture()
      api_key1 = agent1.api_key

      # Create account for agent1
      conn =
        conn
        |> put_req_header("x-api-key", api_key1)
        |> post("/api/v1/accounts", %{
          wallet_name: "Agent 1 Wallet",
          public_address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          currency: "USD"
        })

      assert %{"data" => %{"agent_id" => created_agent_id}} = json_response(conn, 201)
      assert created_agent_id == agent1.id
      assert created_agent_id != agent2.id
    end
  end
end
