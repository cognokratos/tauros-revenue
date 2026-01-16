defmodule TaurosWeb.Api.Admin.LoginController do
  use TaurosWeb, :controller

  alias Tauros.Accounts

  def create(conn, params) do
    case login_admin(params || %{}) do
      {:ok, user} ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:ok)
        |> json(%{data: %{token: "Bearer #{token}"}})

      {:error, :invalid_email_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "invalid_credentials",
            message: "Invalid email or password",
            details: %{}
          }
        })

      {:error, :missing_params} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "invalid_request",
            message: "Missing required parameters: email and password",
            details: %{}
          }
        })
    end
  end

  defp login_admin(%{"email" => email, "password" => password})
       when is_binary(email) and is_binary(password) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user -> {:ok, user}
      nil -> {:error, :invalid_email_password}
    end
  end

  defp login_admin(%{"email" => _email, "password" => _password}),
    do: {:error, :invalid_email_password}

  defp login_admin(_), do: {:error, :missing_params}
end
