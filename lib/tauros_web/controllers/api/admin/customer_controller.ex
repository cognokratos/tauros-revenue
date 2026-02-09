defmodule TaurosWeb.Api.Admin.CustomerController do
  use TaurosWeb, :controller

  alias Tauros.Customers
  alias Tauros.Customers.Customer

  action_fallback TaurosWeb.Api.Admin.FallbackController

  @doc """
  POST /api/admin/v1/customers
  Create a new customer.
  """
  def create(conn, %{"customer" => customer_params}) do
    with {:ok, %Customer{} = customer} <-
           Customers.create_customer(conn.assigns.current_scope, customer_params) do
      conn
      |> put_status(:created)
      |> render(:show, customer: customer)
    end
  end

  @doc """
  GET /api/admin/v1/customers
  List all customers owned by the current admin.
  """
  def list(conn, _params) do
    customers = Customers.list_customers(conn.assigns.current_scope)
    render(conn, :index, customers: customers)
  end

  @doc """
  GET /api/admin/v1/customers/:id
  Get a specific customer.
  """
  def show(conn, %{"id" => id}) do
    customer = Customers.get_customer!(conn.assigns.current_scope, id)
    render(conn, :show, customer: customer)
  end

  @doc """
  PATCH /api/admin/v1/customers/:id
  Update a customer.
  """
  def update(conn, %{"id" => id, "customer" => customer_params}) do
    customer = Customers.get_customer!(conn.assigns.current_scope, id)

    with {:ok, %Customer{} = customer} <-
           Customers.update_customer(conn.assigns.current_scope, customer, customer_params) do
      render(conn, :show, customer: customer)
    end
  end

  @doc """
  DELETE /api/admin/v1/customers/:id
  Delete a customer.
  """
  def delete(conn, %{"id" => id}) do
    customer = Customers.get_customer!(conn.assigns.current_scope, id)

    with {:ok, %Customer{}} <- Customers.delete_customer(conn.assigns.current_scope, customer) do
      send_resp(conn, :no_content, "")
    end
  end
end
