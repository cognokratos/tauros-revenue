defmodule TaurosWeb.AgentLiveTest do
  use TaurosWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures

  describe "Agents Index" do
    setup :register_and_log_in_user

    test "renders list of agents for logged in user", %{conn: conn, user: user} do
      _agent1 = agent_fixture(user_id: user.id, name: "Agent 1")
      _agent2 = agent_fixture(user_id: user.id, name: "Agent 2")

      {:ok, view, _html} = live(conn, ~p"/agents")

      assert has_element?(view, "#agents", "Agent 1")
      assert has_element?(view, "#agents", "Agent 2")
    end

    test "does not show agents from other users", %{conn: conn, user: user} do
      other_user = user_fixture()
      _other_agent = agent_fixture(user_id: other_user.id, name: "Other User Agent")
      _my_agent = agent_fixture(user_id: user.id, name: "My Agent")

      {:ok, view, _html} = live(conn, ~p"/agents")

      assert has_element?(view, "#agents", "My Agent")
      refute has_element?(view, "#agents", "Other User Agent")
    end

    test "delete agent removes it from the list", %{conn: conn, user: user} do
      _agent = agent_fixture(user_id: user.id, name: "Delete Me")

      {:ok, view, _html} = live(conn, ~p"/agents")

      assert has_element?(view, "#agents", "Delete Me")

      view
      |> element("a[data-confirm='Are you sure?']", "Delete")
      |> render_click()

      refute has_element?(view, "#agents", "Delete Me")
    end

    test "navigate to new agent form from index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/agents")

      assert has_element?(view, "a[href='/agents/new']")
    end
  end

  describe "New Agent Form" do
    setup :register_and_log_in_user

    test "form renders with name and api_key inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/agents/new")

      assert has_element?(view, "#agent-form")
      assert has_element?(view, "input[name='agent[name]']")
      assert has_element?(view, "input[name='agent[api_key]']")
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/agents/new")

      html =
        view
        |> form("#agent-form", agent: %{name: "", api_key: ""})
        |> render_submit()

      # Check for validation errors
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "creates agent from provided API key", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/agents/new")

      external_api_key = "key_from_external_service_12345"

      assert {:error, {:live_redirect, %{to: "/agents"}}} =
               view
               |> form("#agent-form",
                 agent: %{name: "My Agent", api_key: external_api_key}
               )
               |> render_submit()

      # Verify agent was created in database
      agent = Tauros.Repo.get_by(Tauros.Agents.Agent, name: "My Agent")
      assert agent != nil
      assert agent.user_id == user.id
      # Verify key is hashed
      assert agent.api_key_hash != external_api_key
      assert Bcrypt.verify_pass(external_api_key, agent.api_key_hash)
    end
  end

  describe "Edit Agent Form" do
    setup :register_and_log_in_user

    test "form renders for editing", %{conn: conn, user: user} do
      agent = agent_fixture(user_id: user.id, name: "Edit Me")

      {:ok, view, _html} = live(conn, ~p"/agents/#{agent}/edit")

      assert has_element?(view, "#agent-form")
      assert has_element?(view, "input[value='Edit Me']")
    end

    test "updates agent name", %{conn: conn, user: user} do
      agent = agent_fixture(user_id: user.id, name: "Old Name")

      {:ok, view, _html} = live(conn, ~p"/agents/#{agent}/edit")

      view
      |> form("#agent-form", agent: %{name: "New Name", api_key: "new_key"})
      |> render_submit()

      # Verify update in database
      updated_agent = Tauros.Repo.get!(Tauros.Agents.Agent, agent.id)
      assert updated_agent.name == "New Name"
    end
  end

  describe "Show Agent" do
    setup :register_and_log_in_user

    test "displays agent details", %{conn: conn, user: user} do
      agent = agent_fixture(user_id: user.id, name: "Test Agent")

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent}")

      assert html =~ "Test Agent"
      assert html =~ agent.id
    end
  end

  describe "Authentication required" do
    test "redirects to login if not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/agents")

      # Should redirect to login page or home
      assert redirect_to =~ "/users/log_in" or redirect_to =~ "/"
    end
  end
end
