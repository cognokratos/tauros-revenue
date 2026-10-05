defmodule TaurosWeb.AgentLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Index" do
    test "lists only the signed-in human's agents", %{conn: conn, user: user} do
      mine = agent(user, name: "My Agent")
      theirs = agent(user(), name: "Other User Agent")

      {:ok, view, _html} = live(conn, ~p"/agents")

      assert has_element?(view, "#agents-#{mine.id}", "My Agent")
      refute has_element?(view, "#agents-#{theirs.id}")
    end

    test "deletes an agent", %{conn: conn, user: user} do
      agent = agent(user)
      {:ok, view, _html} = live(conn, ~p"/agents")

      view |> element("#agents-#{agent.id} a", "Delete") |> render_click()

      refute has_element?(view, "#agents-#{agent.id}")
    end

    test "refuses to delete an agent that owns customers", %{conn: conn, user: user} do
      agent = agent(user)
      customer(agent)
      {:ok, view, _html} = live(conn, ~p"/agents")

      view |> element("#agents-#{agent.id} a", "Delete") |> render_click()

      assert has_element?(view, "#agents-#{agent.id}")
      assert render(view) =~ "cannot be deleted"
    end
  end

  describe "New" do
    test "validates the name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/agents/new")

      html = view |> form("#agent-form", agent: %{name: ""}) |> render_submit()

      assert html =~ "is required"
      refute has_element?(view, "#api-key-notice")
    end

    test "shows the generated API key exactly once", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/agents/new")

      view |> form("#agent-form", agent: %{name: "Billing bot"}) |> render_submit()

      assert [agent] = Tauros.Accounts.list_agents!(actor: user)
      assert agent.name == "Billing bot"
      key = view |> element("#api-key") |> render() |> LazyHTML.from_fragment() |> LazyHTML.text()
      assert "tauros_" <> _ = String.trim(key)

      {:ok, show, _html} = live(conn, ~p"/agents/#{agent}")
      refute has_element?(show, "#api-key")
    end
  end

  describe "Edit" do
    test "renames the agent", %{conn: conn, user: user} do
      agent = agent(user, name: "Old Name")
      {:ok, view, _html} = live(conn, ~p"/agents/#{agent}/edit")

      assert {:error, {:live_redirect, %{to: "/agents"}}} =
               view |> form("#agent-form", agent: %{name: "New Name"}) |> render_submit()

      assert Tauros.Accounts.get_agent!(agent.id, actor: user).name == "New Name"
    end
  end

  describe "Show" do
    test "displays the agent and rotates its key", %{conn: conn, user: user} do
      agent = agent(user, name: "Test Agent")
      {:ok, view, html} = live(conn, ~p"/agents/#{agent}")

      assert html =~ "Test Agent"
      refute has_element?(view, "#api-key")

      view |> element("#rotate-api-key") |> render_click()

      assert has_element?(view, "#api-key")
      refute render(view) =~ agent.__metadata__.api_key
    end

    test "is not reachable for other humans' agents", %{conn: conn} do
      agent = agent(user())

      assert_raise Ash.Error.Invalid, fn -> live(conn, ~p"/agents/#{agent}") end
    end
  end

  test "requires authentication" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/agents")
  end
end
