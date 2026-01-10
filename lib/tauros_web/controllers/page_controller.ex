defmodule TaurosWeb.PageController do
  use TaurosWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
