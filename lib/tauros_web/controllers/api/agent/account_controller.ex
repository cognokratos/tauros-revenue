defmodule TaurosWeb.Api.Agent.AccountController do
  use TaurosWeb, :controller

  alias Tauros.Wallets

  action_fallback TaurosWeb.Api.Agent.FallbackController

  @doc """
  Creates a new wallet account for the authenticated agent.

  Requires:
    - X-API-KEY header with valid agent API key
    - Request body with: wallet_name, public_address, currency

  Returns:
    - 201 Created with account JSON on success
    - 401 Unauthorized if API key is missing or invalid
    - 422 Unprocessable Entity if validation fails
  """
  def create(conn, params) do
    agent = conn.assigns.current_agent

    # Handle both flat params and nested {"account" => params} format
    account_params = params["account"] || params

    case Wallets.create_account(agent, account_params) do
      {:ok, account} ->
        conn
        |> put_status(:created)
        |> render(:show, account: account)

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
