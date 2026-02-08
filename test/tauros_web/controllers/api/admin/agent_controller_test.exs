defmodule TaurosWeb.Api.Admin.AgentControllerTest do
  use TaurosWeb.ConnCase

  import Tauros.AccountsFixtures

  setup [:create_and_authenticate_admin_user]

  describe "POST /api/admin/v1/agents" do
    test "creates an agent with valid token and parameters", %{conn: conn, user: user} do
      api_key = "external_service_api_key_12345"

      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "Test Agent", api_key: api_key})

      assert conn.status == 201

      response = json_response(conn, 201)

      assert response["agent"]["name"] == "Test Agent"
      assert response["agent"]["user_id"] == user.id
      refute Map.has_key?(response, "api_key")
    end

    test "returns 401 with missing bearer token", %{conn: conn} do
      conn = Plug.Conn.delete_req_header(conn, "authorization")
      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "Test Agent", api_key: "key"})

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["code"] == "unauthorized"
      assert response["error"]["message"] == "Invalid or missing bearer token"
    end

    test "returns 401 with invalid bearer token", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> Plug.Conn.put_req_header("authorization", "Bearer invalid_token")

      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "Test Agent", api_key: "key"})

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["code"] == "unauthorized"
    end

    test "returns 422 with missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/v1/agents", %{})

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"]["code"] == "missing_required_fields"
      assert response["error"]["details"]["required"] == ["name", "api_key"]
    end

    test "returns 422 when name is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/v1/agents", %{api_key: "some_key"})

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"]["code"] == "missing_required_fields"
    end

    test "returns 422 when api_key is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "Test Agent"})

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"]["code"] == "validation_error"
      assert is_map(response["error"]["details"])
    end

    test "returns 422 with validation error when name is empty", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "", api_key: "key"})

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"]["code"] == "validation_error"
      assert is_map(response["error"]["details"])
    end
  end

  describe "API Key Storage and Security" do
    test "API key is hashed in database", %{conn: conn} do
      plaintext_key = "plaintext_api_key_from_external_service"

      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "Secure Agent", api_key: plaintext_key})
      _response = json_response(conn, 201)

      agent = Tauros.Repo.get_by(Tauros.Agents.Agent, name: "Secure Agent")
      assert agent != nil
      assert agent.api_key_hash != nil
      assert agent.api_key_hash != plaintext_key
      assert Bcrypt.verify_pass(plaintext_key, agent.api_key_hash)
    end

    test "created agent is scoped to authenticated user", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/admin/v1/agents", %{name: "User Agent", api_key: "external_key"})

      _response = json_response(conn, 201)

      agent = Tauros.Repo.get_by(Tauros.Agents.Agent, name: "User Agent")
      assert agent.user_id == user.id
    end

    test "API response does not include plaintext API key", %{conn: conn} do
      conn = post(conn, ~p"/api/admin/v1/agents", %{name: "No Key Agent", api_key: "secret_key"})
      response = json_response(conn, 201)

      refute Map.has_key?(response, "api_key")
      assert response["agent"]["name"] == "No Key Agent"
    end
  end

  defp create_and_authenticate_admin_user(%{conn: conn}) do
    user = user_fixture()
    api_token = Tauros.Accounts.create_user_api_token(user)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_token}")

    {:ok, conn: conn, user: user}
  end
end
