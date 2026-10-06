defmodule TaurosWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TaurosWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TaurosWeb.Endpoint

      use TaurosWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TaurosWeb.ConnCase
      import Tauros.Fixtures
    end
  end

  setup tags do
    Tauros.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and signs in a human user.

      setup :register_and_log_in_user
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Tauros.Fixtures.user()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that signs in a human approver.

      setup :register_and_log_in_approver
  """
  def register_and_log_in_approver(%{conn: conn}) do
    user = Tauros.Fixtures.approver()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc "Stores a session token for `user` in the connection."
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(Tauros.Fixtures.with_token(user))
  end

  @doc "Adds an `Authorization: Bearer` header carrying `credential`."
  def authorize(conn, credential) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> credential)
    |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
  end
end
