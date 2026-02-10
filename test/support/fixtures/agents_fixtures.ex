defmodule Tauros.AgentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tauros.Agents` context.
  """

  import Tauros.AccountsFixtures

  @doc """
  Generate an agent with a provided API key.

  Returns the agent with the plaintext api_key stored as a field for testing.
  """
  def agent_fixture(attrs \\ []) do
    attrs = if is_list(attrs), do: Enum.into(attrs, %{}), else: attrs

    user_id = Map.get(attrs, :user_id, user_fixture().id)
    name = Map.get(attrs, :name, "Test Agent")
    api_key = Map.get(attrs, :api_key, "test_api_key_#{System.unique_integer()}")

    {:ok, agent} =
      Tauros.Agents.create_agent(
        %Tauros.Accounts.Scope{user: %{id: user_id}},
        %{"name" => name, "api_key" => api_key}
      )

    # Store plaintext api_key in the agent struct for test access
    %{agent | api_key: api_key}
  end
end
