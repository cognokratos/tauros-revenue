defmodule TaurosWeb.Api.Admin.AgentController do
  use TaurosWeb, :controller

  alias Tauros.Agents

  def create(conn, %{"agent" => params}) do
    current_scope = conn.assigns[:current_scope]

    case Agents.create_agent(current_scope, params) do
      {:ok, agent} ->
        conn
        |> put_status(:created)
        |> json(%{
          agent: %{
            id: agent.id,
            name: agent.name,
            user_id: agent.user_id,
            created_at: agent.inserted_at
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "validation_error",
            message: "Failed to create agent",
            details: changeset_errors(changeset)
          }
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "missing_required_fields",
        message: "The request is missing required fields",
        details: %{required: ["name", "api_key"]}
      }
    })
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
