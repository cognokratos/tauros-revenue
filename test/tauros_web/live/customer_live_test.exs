defmodule TaurosWeb.CustomerLiveTest do
  use TaurosWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures
  import Tauros.CustomersFixtures

  describe "Customers list" do
    test "displays customer page for authenticated user", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      _customer = customer_fixture(%{"agent_id" => agent.id})

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/customers")

      # Check that the page title and header are present
      assert html =~ "Customers"
      assert html =~ "New Customer"

      # Verify the LiveView is working
      assert has_element?(view, "#customers")
    end

    test "shows empty state when no customers", %{conn: conn} do
      user = user_fixture()
      _agent = agent_fixture(%{user_id: user.id})

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/customers")

      assert html =~ "No customers yet"
    end

    test "can navigate to new customer form", %{conn: conn} do
      user = user_fixture()
      _agent = agent_fixture(%{user_id: user.id})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/customers")

      {:ok, _form_view, form_html} =
        view
        |> element("a", "New Customer")
        |> render_click()
        |> follow_redirect(conn)

      assert form_html =~ "New Customer"
    end
  end

  describe "Create customer form" do
    test "shows form fields", %{conn: conn} do
      user = user_fixture()
      _agent = agent_fixture(%{user_id: user.id})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      assert has_element?(view, "#customer-form")
      assert has_element?(view, "input[name='customer[name]']")
      assert has_element?(view, "input[name='customer[email]']")
      assert has_element?(view, "select[name='customer[agent_id]']")
    end

    test "creates a customer successfully", %{conn: conn} do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      view
      |> form("#customer-form", %{
        "customer" => %{
          "name" => "New Customer",
          "email" => "new@example.com",
          "agent_id" => agent.id
        }
      })
      |> render_submit()

      # Should redirect to customers list
      assert_redirected(view, ~p"/customers")
    end

    test "validates required fields", %{conn: conn} do
      user = user_fixture()
      _agent = agent_fixture(%{user_id: user.id})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      # Try to submit with missing fields
      _result =
        view
        |> form("#customer-form", %{"customer" => %{"name" => "Test"}})
        |> render_submit()

      # Form should still be visible
      html = render(view)
      # Check that form is still present (not redirected) which means validation failed
      assert html =~ "customer-form"
    end
  end

  describe "Authentication" do
    test "requires login to view customers", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/customers")
      assert path == ~p"/users/log-in"
    end

    test "requires login to create customer", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/customers/new")
      assert path == ~p"/users/log-in"
    end
  end
end
