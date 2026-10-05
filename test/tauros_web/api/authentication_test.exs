defmodule TaurosWeb.Api.AuthenticationTest do
  use TaurosWeb.ConnCase, async: true

  defp sign_in(conn, email, password) do
    conn
    |> put_req_header("content-type", "application/vnd.api+json")
    |> post("/api/v1/users/sign-in", %{data: %{attributes: %{email: email, password: password}}})
  end

  describe "POST /api/v1/users/sign-in" do
    test "returns a bearer token for valid credentials", %{conn: conn} do
      user = user()

      response = conn |> sign_in(to_string(user.email), valid_password()) |> json_response(201)

      assert %{"meta" => %{"token" => token}, "data" => %{"id" => id}} = response
      assert id == user.id

      conn = build_conn() |> authorize(token) |> get("/api/v1/agents")
      assert json_response(conn, 200)["data"] == []
    end

    test "rejects invalid credentials", %{conn: conn} do
      user = user()

      conn = sign_in(conn, to_string(user.email), "wrong password")

      assert %{"errors" => [%{"code" => "invalid_credentials"}]} = json_response(conn, 401)
    end
  end

  describe "unauthenticated requests" do
    test "without credentials are rejected with 401", %{conn: conn} do
      conn = get(conn, "/api/v1/customers")

      assert %{"errors" => [%{"code" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "with an unknown bearer credential are rejected with 401", %{conn: conn} do
      for credential <- ["not-a-jwt", "tauros_not-a-real-key"] do
        conn = conn |> authorize(credential) |> get("/api/v1/customers")
        assert %{"errors" => [%{"code" => "unauthorized"}]} = json_response(conn, 401)
      end
    end

    test "with a malformed authorization scheme are rejected with 401", %{conn: conn} do
      conn = conn |> put_req_header("authorization", "Basic abc") |> get("/api/v1/customers")
      assert json_response(conn, 401)
    end
  end

  describe "agent API keys" do
    test "authenticate the agent", %{conn: conn} do
      agent = agent(user())

      conn =
        conn |> authorize(agent.__metadata__.plaintext_api_key) |> get("/api/v1/wallet-accounts")

      assert json_response(conn, 200)["data"] == []
    end
  end
end
