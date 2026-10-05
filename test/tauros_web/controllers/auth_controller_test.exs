defmodule TaurosWeb.AuthControllerTest do
  use TaurosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "signing out clears the session and redirects", %{conn: conn} do
    conn = delete(conn, ~p"/sign-out")

    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(recycle(conn), ~p"/")
  end
end
