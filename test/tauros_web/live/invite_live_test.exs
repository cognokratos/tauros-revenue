defmodule TaurosWeb.InviteLiveTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "as an approver" do
    setup :register_and_log_in_approver

    test "invites a human with a role", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/invite")

      view
      |> form("#invite-form", user: %{email: "ops@example.com", role: "operator"})
      |> render_submit()

      assert [invited] =
               Tauros.Accounts.User
               |> Ash.Query.filter_input(email: "ops@example.com")
               |> Ash.read!(authorize?: false)

      assert invited.role == :operator
    end
  end

  describe "as an operator" do
    setup :register_and_log_in_user

    test "the page explains that only approvers can invite", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/invite")

      assert has_element?(view, "#invite-forbidden", "Only approvers")
      refute has_element?(view, "#invite-form")
    end
  end
end
