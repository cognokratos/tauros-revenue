defmodule Tauros.Accounts.AgentTest do
  use Tauros.DataCase, async: true

  alias Tauros.{Accounts, Revenue}

  defp sign_in(api_key) do
    Accounts.Agent
    |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: api_key})
    |> Ash.read_one()
  end

  describe "create_agent" do
    test "belongs to the human who created it" do
      user = user()

      assert {:ok, agent} = Accounts.create_agent("Billing bot", actor: user)
      assert agent.name == "Billing bot"
      assert agent.user_id == user.id
    end

    test "issues an API key exactly once and stores only its hash" do
      agent = agent(user())
      api_key = agent.__metadata__.api_key

      assert "tauros_" <> _ = api_key
      assert {:ok, %{id: id}} = sign_in(api_key)
      assert id == agent.id

      [stored] = Ash.read!(Accounts.ApiKey, authorize?: false)
      refute stored.api_key_hash == api_key

      refute Map.has_key?(
               Ash.get!(Accounts.Agent, agent.id, authorize?: false).__metadata__,
               :api_key
             )
    end

    test "requires a name" do
      assert {:error, %Ash.Error.Invalid{}} = Accounts.create_agent("", actor: user())
    end

    test "cannot be done by an agent" do
      agent = agent(user())
      assert {:error, %Ash.Error.Forbidden{}} = Accounts.create_agent("Child", actor: agent)
    end

    test "cannot be done anonymously" do
      assert {:error, _} = Accounts.create_agent("Orphan")
    end
  end

  describe "API key sign-in" do
    test "rejects unknown keys" do
      agent(user())
      refute match?({:ok, %Accounts.Agent{}}, sign_in("tauros_not-a-real-key"))
    end

    test "rotation revokes the previous key" do
      user = user()
      agent = agent(user)
      old_key = agent.__metadata__.api_key

      rotated = Accounts.rotate_agent_api_key!(agent, actor: user)
      new_key = rotated.__metadata__.api_key

      assert new_key != old_key
      refute match?({:ok, %Accounts.Agent{}}, sign_in(old_key))
      assert {:ok, %{id: id}} = sign_in(new_key)
      assert id == agent.id
    end
  end

  describe "ownership" do
    setup do
      owner = user()
      %{owner: owner, other: user(), agent: agent(owner)}
    end

    test "humans list only their own agents", %{owner: owner, other: other, agent: agent} do
      _foreign = agent(other)

      assert [%{id: id}] = Accounts.list_agents!(actor: owner)
      assert id == agent.id
    end

    test "other humans cannot read, update, rotate or delete the agent", ctx do
      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_agent(ctx.agent.id, actor: ctx.other)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_agent(ctx.agent, %{name: "Mine now"}, actor: ctx.other)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.rotate_agent_api_key(ctx.agent, actor: ctx.other)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.destroy_agent(ctx.agent, actor: ctx.other)
    end

    test "an agent cannot manage itself", %{agent: agent} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_agent(agent, %{name: "Promoted"}, actor: agent)

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.rotate_agent_api_key(agent, actor: agent)
    end

    test "the owner can rename and delete the agent", %{owner: owner, agent: agent} do
      assert {:ok, %{name: "Renamed"}} =
               Accounts.update_agent(agent, %{name: "Renamed"}, actor: owner)

      assert :ok = Accounts.destroy_agent(agent, actor: owner)
      assert [] = Accounts.list_agents!(actor: owner)
    end
  end

  describe "destroy_agent" do
    test "is refused while the agent owns customers" do
      owner = user()
      agent = agent(owner)
      customer(agent)

      assert {:error, %Ash.Error.Invalid{}} = Accounts.destroy_agent(agent, actor: owner)
    end

    test "is refused while the agent owns wallet accounts" do
      owner = user()
      agent = agent(owner)
      wallet_account(agent)

      assert {:error, %Ash.Error.Invalid{}} = Accounts.destroy_agent(agent, actor: owner)
      assert [_] = Revenue.list_wallet_accounts!(actor: owner)
    end
  end
end
