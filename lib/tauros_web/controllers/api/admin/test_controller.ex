defmodule TaurosWeb.Api.Admin.TestController do
  use TaurosWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
