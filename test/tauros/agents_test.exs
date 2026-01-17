defmodule Tauros.AgentsTest do
  use Tauros.DataCase

  alias Tauros.Agents
  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures

  describe "agents" do
    alias Tauros.Agents.Agent

    test "list_agents_for_user/1 returns agents for a user" do
      user = user_fixture()
      agent1 = agent_fixture(user_id: user.id, name: "Agent 1")
      agent2 = agent_fixture(user_id: user.id, name: "Agent 2")

      agents = Agents.list_agents_for_user(user.id)
      assert length(agents) == 2
      assert Enum.find(agents, &(&1.id == agent1.id))
      assert Enum.find(agents, &(&1.id == agent2.id))
    end

    test "get_agent!/1 returns the agent with given id" do
      agent = agent_fixture()
      assert Agents.get_agent!(agent.id).id == agent.id
    end

    test "create_agent/2 with valid data creates an agent" do
      user = user_fixture()
      scope = %Tauros.Accounts.Scope{user: user}
      api_key = "test_key_from_external_service"

      assert {:ok, %Agent{} = agent} =
               Agents.create_agent(scope, %{"name" => "Test Agent", "api_key" => api_key})

      assert agent.name == "Test Agent"
      assert agent.user_id == user.id
      assert Bcrypt.verify_pass(api_key, agent.api_key_hash)
    end

    test "create_agent/2 validates required fields" do
      user = user_fixture()
      scope = %Tauros.Accounts.Scope{user: user}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Agents.create_agent(scope, %{"name" => ""})

      assert changeset.errors[:name]
    end

    test "create_agent/2 requires api_key" do
      user = user_fixture()
      scope = %Tauros.Accounts.Scope{user: user}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Agents.create_agent(scope, %{"name" => "Test Agent"})

      assert changeset.errors[:api_key]
    end

    test "create_agent/2 stores API key hashed, not plaintext" do
      user = user_fixture()
      scope = %Tauros.Accounts.Scope{user: user}
      api_key = "plaintext_key_from_service"

      {:ok, agent} = Agents.create_agent(scope, %{"name" => "Secure Agent", "api_key" => api_key})

      # Stored hash should not equal plaintext
      assert agent.api_key_hash != api_key
      # But should verify correctly
      assert Bcrypt.verify_pass(api_key, agent.api_key_hash)
    end

    test "update_agent/2 with valid data updates the agent" do
      agent = agent_fixture()
      update_attrs = %{"name" => "Updated Name"}

      assert {:ok, %Agent{} = updated} = Agents.update_agent(agent, update_attrs)
      assert updated.name == "Updated Name"
    end

    test "update_agent/2 with invalid data returns error changeset" do
      agent = agent_fixture()
      assert {:error, %Ecto.Changeset{}} = Agents.update_agent(agent, %{"name" => ""})
      assert agent.id == Agents.get_agent!(agent.id).id
    end

    test "delete_agent/1 deletes the agent" do
      agent = agent_fixture()
      assert {:ok, %Agent{}} = Agents.delete_agent(agent)
      assert_raise Ecto.NoResultsError, fn -> Agents.get_agent!(agent.id) end
    end

    test "change_agent/1 returns an agent changeset" do
      agent = agent_fixture()
      assert %Ecto.Changeset{} = Agents.change_agent(agent)
    end
  end
end
