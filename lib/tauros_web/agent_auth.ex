defmodule TaurosWeb.AgentAuth do
  @moduledoc """
  Authentication and authorization plugs for agent API endpoints.

  Agents authenticate via X-API-KEY header containing their plaintext API key.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Tauros.Agents

  @doc """
  Plug initialization callback.
  """
  def init(opts), do: opts

  @doc """
  Standard Plug interface - requires valid agent API key.

  Called by router pipelines. Halts request if API key invalid/missing.
  """
  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key] ->
        case Agents.get_agent_by_api_key(api_key) do
          {:ok, agent} ->
            assign(conn, :current_agent, agent)

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{
              error: %{
                code: "unauthorized",
                message: "Invalid API key",
                details: %{}
              }
            })
            |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "unauthorized",
            message: "Missing X-API-KEY header",
            details: %{}
          }
        })
        |> halt()
    end
  end

  @doc """
  Alternative plug for optional agent auth - does not halt on failure.

  Returns conn with `:current_agent` assigned if valid, or unchanged conn if invalid.
  """
  def fetch_current_agent(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key] ->
        case Agents.get_agent_by_api_key(api_key) do
          {:ok, agent} ->
            assign(conn, :current_agent, agent)

          {:error, _reason} ->
            conn
        end

      _ ->
        conn
    end
  end
end
