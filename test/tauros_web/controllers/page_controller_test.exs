defmodule TaurosWeb.PageControllerTest do
  use TaurosWeb.ConnCase

  test "GET / redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) =~ ~p"/users/log-in"
  end
end
