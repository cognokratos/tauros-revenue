defmodule TaurosWeb.Api.Admin.FallbackController do
  @moduledoc """
  Fallback controller for admin API error handling.
  """
  use TaurosWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TaurosWeb.Api.Admin.ErrorJSON)
    |> render(:changeset_errors, changeset: changeset)
  end

  def call(conn, {:error, msg}) when is_binary(msg) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TaurosWeb.Api.Admin.ErrorJSON)
    |> render(:error, message: msg)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: TaurosWeb.Api.Admin.ErrorJSON)
    |> render(:error, message: "Not found")
  end
end
