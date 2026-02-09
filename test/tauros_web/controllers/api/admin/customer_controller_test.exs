defmodule TaurosWeb.Api.Admin.CustomerControllerTest do
  use TaurosWeb.ConnCase

  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures
  import Tauros.CustomersFixtures

  describe "POST /api/admin/v1/customers" do
    test "creates a customer with valid data", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/admin/v1/customers", %{
          "customer" => %{
            "name" => "Acme Inc",
            "email" => "contact@acme.com",
            "agent_id" => agent.id
          }
        })

      response = json_response(conn, 201)
      assert response["data"]["name"] == "Acme Inc"
      assert response["data"]["email"] == "contact@acme.com"
      assert response["data"]["agent_id"] == agent.id
    end

    test "returns 422 when missing required fields", %{conn: conn} do
      user = user_fixture()
      _agent = agent_fixture(%{user_id: user.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/admin/v1/customers", %{
          "customer" => %{
            "name" => "Acme Inc"
          }
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "validation_error"
    end

    test "returns 401 without valid Bearer token", %{conn: conn} do
      agent_id = agent_fixture().id

      conn =
        post(conn, ~p"/api/admin/v1/customers", %{
          "customer" => %{
            "name" => "Acme Inc",
            "email" => "contact@acme.com",
            "agent_id" => agent_id
          }
        })

      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "returns error when agent doesn't belong to user", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      other_agent = agent_fixture(%{user_id: other_user.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/admin/v1/customers", %{
          "customer" => %{
            "name" => "Acme Inc",
            "email" => "contact@acme.com",
            "agent_id" => other_agent.id
          }
        })

      assert json_response(conn, 422)["error"]["code"] == "validation_error"
    end
  end

  describe "GET /api/admin/v1/customers" do
    test "lists customers for the user", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/admin/v1/customers")

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert Enum.find(response["data"], &(&1["id"] == customer.id))
    end

    test "returns 401 without valid Bearer token", %{conn: conn} do
      conn = get(conn, ~p"/api/admin/v1/customers")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end

  describe "GET /api/admin/v1/customers/:id" do
    test "returns a customer", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/admin/v1/customers/#{customer.id}")

      response = json_response(conn, 200)
      assert response["data"]["id"] == customer.id
      assert response["data"]["name"] == customer.name
    end

    test "returns 401 without token", %{conn: conn} do
      customer = customer_fixture()
      conn = get(conn, ~p"/api/admin/v1/customers/#{customer.id}")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end

  describe "PATCH /api/admin/v1/customers/:id" do
    test "updates a customer", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/admin/v1/customers/#{customer.id}", %{
          "customer" => %{"name" => "Updated Name"}
        })

      response = json_response(conn, 200)
      assert response["data"]["name"] == "Updated Name"
    end

    test "rejects agent_id reassignment with 422 error", %{conn: conn} do
      user = user_fixture()
      agent1 = agent_fixture(%{user_id: user.id})
      agent2 = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent1.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/admin/v1/customers/#{customer.id}", %{
          "customer" => %{"agent_id" => agent2.id}
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "validation_error"
    end

    test "ignores agent_id in update params when present with other fields", %{conn: conn} do
      user = user_fixture()
      agent1 = agent_fixture(%{user_id: user.id})
      agent2 = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent1.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> patch(~p"/api/admin/v1/customers/#{customer.id}", %{
          "customer" => %{"name" => "New Name", "agent_id" => agent2.id}
        })

      response = json_response(conn, 422)
      assert response["error"]["code"] == "validation_error"
      # Verify agent_id was not changed
      customer = Tauros.Customers.get_customer!(%Tauros.Accounts.Scope{user: user}, customer.id)
      assert customer.agent_id == agent1.id
    end
  end

  describe "DELETE /api/admin/v1/customers/:id" do
    test "deletes a customer", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      token = generate_admin_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/admin/v1/customers/#{customer.id}")

      assert response(conn, 204)
    end
  end

  defp generate_admin_token(user) do
    Tauros.Accounts.create_user_api_token(user)
  end
end
