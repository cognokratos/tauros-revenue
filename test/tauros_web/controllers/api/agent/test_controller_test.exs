defmodule TaurosWeb.Api.Agent.TestControllerTest do
  use TaurosWeb.ConnCase

  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "GET /api/v1/test - agent verification" do
    test "returns 200 with valid API key", %{user: user} do
      api_key = "test_key_12345"
      agent_fixture(user_id: user.id, name: "Test Agent", api_key: api_key)

      conn =
        build_conn()
        |> put_req_header("x-api-key", api_key)
        |> get("/api/v1/test")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    test "returns 401 with missing X-API-KEY header", %{} do
      conn = build_conn() |> get("/api/v1/test")

      assert response(conn, 401)
    end

    test "returns 401 with invalid API key", %{user: user} do
      agent_fixture(user_id: user.id, name: "Test Agent", api_key: "valid_key")

      conn =
        build_conn()
        |> put_req_header("x-api-key", "invalid_key")
        |> get("/api/v1/test")

      assert response(conn, 401)
    end

    test "returns 401 when no agent matches the API key", %{} do
      conn =
        build_conn()
        |> put_req_header("x-api-key", "nonexistent_key")
        |> get("/api/v1/test")

      assert response(conn, 401)
    end
  end
end
