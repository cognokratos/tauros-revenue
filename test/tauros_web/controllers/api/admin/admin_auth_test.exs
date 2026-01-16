defmodule TaurosWeb.Controllers.Api.Admin.AdminAuthTest do
  use TaurosWeb.ConnCase

  import Tauros.AccountsFixtures

  describe "admin authentication via bearer token" do
    test "unauthorized request without bearer token returns 401 with REST error envelope", %{
      conn: conn
    } do
      conn = get(conn, "/api/admin/v1/test")

      assert conn.status == 401

      assert response = json_response(conn, 401)
      assert is_map(response["error"])
      assert response["error"]["code"]
      assert response["error"]["message"]
      assert is_map(response["error"]["details"])
    end

    test "invalid/malformed authorization header returns 401 with REST error envelope", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("authorization", "invalid-token")
        |> get("/api/admin/v1/test")

      assert conn.status == 401

      assert response = json_response(conn, 401)
      assert is_map(response["error"])
      assert response["error"]["code"]
      assert response["error"]["message"]
    end

    test "malformed bearer scheme returns 401 with REST error envelope", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "NotBearer token123")
        |> get("/api/admin/v1/test")

      assert conn.status == 401

      assert response = json_response(conn, 401)
      assert is_map(response["error"])
      assert response["error"]["code"]
    end

    test "valid bearer token assigns current_scope with user", %{conn: conn} do
      user = user_fixture()
      token = Tauros.Accounts.create_user_api_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/admin/v1/test")

      # We expect a 200 or similar - the important part is the token was accepted
      assert conn.status == 200
      assert conn.assigns[:current_scope]
      assert conn.assigns.current_scope.user.id == user.id
    end
  end

  describe "admin login endpoint" do
    test "POST /api/admin/v1/login with valid credentials returns bearer token", %{
      conn: conn
    } do
      user = user_fixture(email: "admin@example.com")
      Tauros.Accounts.update_user_password(user, %{password: "ValidPassword123!"})

      conn =
        post(conn, "/api/admin/v1/login", %{
          "email" => "admin@example.com",
          "password" => "ValidPassword123!"
        })

      assert conn.status == 200

      response = json_response(conn, 200)
      assert response["data"]
      assert response["data"]["token"]
      assert String.starts_with?(response["data"]["token"], "Bearer ")
    end

    test "POST /api/admin/v1/login with invalid credentials returns 401 with error envelope",
         %{conn: conn} do
      user = user_fixture(email: "admin@example.com")
      Tauros.Accounts.update_user_password(user, %{password: "ValidPassword123!"})

      conn =
        post(conn, "/api/admin/v1/login", %{
          "email" => "admin@example.com",
          "password" => "WrongPassword"
        })

      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["error"]
      assert response["error"]["code"]
      assert response["error"]["message"]
    end

    test "POST /api/admin/v1/login with missing parameters returns 422 with error envelope", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/admin/v1/login", %{
          "email" => "admin@example.com"
        })

      assert conn.status == 422

      response = json_response(conn, 422)
      assert response["error"]
      assert response["error"]["code"]
      assert response["error"]["message"]
    end
  end
end
