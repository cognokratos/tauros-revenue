defmodule TaurosWeb.CustomerLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  setup %{user: user}, do: %{agent: agent(user, name: "Primary Agent")}

  describe "Index" do
    test "lists customers of the human's agents with their agent", %{conn: conn, agent: agent} do
      customer = customer(agent, name: "Acme Inc")
      foreign = customer(agent(user()))

      {:ok, view, _html} = live(conn, ~p"/customers")

      assert has_element?(view, "#customers-#{customer.id}", "Acme Inc")
      assert has_element?(view, "#customers-#{customer.id}", "Primary Agent")
      refute has_element?(view, "#customers-#{foreign.id}")
      refute has_element?(view, "#empty-state")
    end

    test "shows an empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/customers")
      assert has_element?(view, "#empty-state")
    end

    test "deletes a customer", %{conn: conn, agent: agent} do
      customer = customer(agent)
      {:ok, view, _html} = live(conn, ~p"/customers")

      view |> element("#customers-#{customer.id} a", "Delete") |> render_click()

      refute has_element?(view, "#customers-#{customer.id}")
      assert has_element?(view, "#empty-state")
    end
  end

  describe "New" do
    test "offers only the human's agents", %{conn: conn, agent: agent} do
      foreign = agent(user(), name: "Foreign Agent")
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      assert has_element?(view, "select[name='customer[agent_id]'] option[value='#{agent.id}']")
      refute has_element?(view, "select[name='customer[agent_id]'] option[value='#{foreign.id}']")
    end

    test "creates a customer", %{conn: conn, user: user, agent: agent} do
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      assert {:error, {:live_redirect, %{to: "/customers"}}} =
               view
               |> form("#customer-form",
                 customer: %{name: "New Customer", email: "new@example.com", agent_id: agent.id}
               )
               |> render_submit()

      assert [%{name: "New Customer", agent_id: agent_id}] =
               Tauros.Revenue.list_customers!(actor: user)

      assert agent_id == agent.id
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/customers/new")

      html = view |> form("#customer-form", customer: %{name: "Test"}) |> render_submit()

      assert html =~ "is required"
      assert has_element?(view, "#customer-form")
    end
  end

  describe "Edit" do
    test "shows the owning agent read-only and keeps it on save", %{
      conn: conn,
      user: user,
      agent: agent
    } do
      customer = customer(agent)
      {:ok, view, _html} = live(conn, ~p"/customers/#{customer}/edit")

      assert has_element?(view, "#customer-agent", "Primary Agent")
      refute has_element?(view, "[name='customer[agent_id]']")

      assert {:error, {:live_redirect, %{to: "/customers"}}} =
               view
               |> form("#customer-form",
                 customer: %{name: "Updated", email: "updated@example.com"}
               )
               |> render_submit()

      updated = Tauros.Revenue.get_customer!(customer.id, actor: user)
      assert {updated.name, updated.agent_id} == {"Updated", agent.id}
    end
  end

  test "Show displays the customer and its agent", %{conn: conn, agent: agent} do
    customer = customer(agent, name: "Acme Inc")
    {:ok, _view, html} = live(conn, ~p"/customers/#{customer}")

    assert html =~ "Acme Inc"
    assert html =~ "Primary Agent"
  end

  test "requires authentication" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/customers/new")
  end
end
