defmodule TaurosWeb.Api.Agent.FallbackController do
  use TaurosWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TaurosWeb.Api.Agent.ErrorJSON)
    |> render("changeset_errors.json", changeset: changeset)
  end

  def call(conn, {:error, _reason}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TaurosWeb.Api.Agent.ErrorJSON)
    |> render("error.json", message: "The request could not be processed")
  end
end
