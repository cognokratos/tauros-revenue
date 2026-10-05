defmodule Tauros.Revenue.CustomerTest do
  use Tauros.DataCase, async: true

  alias Tauros.Revenue

  setup do
    owner = user()
    %{owner: owner, agent: agent(owner), other: user()}
  end

  defp attrs(agent, overrides \\ %{}) do
    Map.merge(%{name: "ACME Inc", email: "contact@acme.com", agent_id: agent.id}, overrides)
  end

  describe "create_customer" do
    test "associates the customer with the owner's agent", %{owner: owner, agent: agent} do
      assert {:ok, customer} = Revenue.create_customer(attrs(agent), actor: owner)
      assert customer.name == "ACME Inc"
      assert customer.email == "contact@acme.com"
      assert customer.agent_id == agent.id
    end

    test "requires name, email and agent", %{owner: owner} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Revenue.create_customer(%{}, actor: owner)

      assert errors |> Enum.map(& &1.field) |> Enum.sort() == [:agent_id, :email, :name]
    end

    test "validates the email format", %{owner: owner, agent: agent} do
      assert {:error, %Ash.Error.Invalid{}} =
               Revenue.create_customer(attrs(agent, %{email: "not an email"}), actor: owner)
    end

    test "is forbidden for an agent owned by someone else", %{other: other, agent: agent} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.create_customer(attrs(agent), actor: other)

      assert [] = Ash.read!(Revenue.Customer, authorize?: false)
    end

    test "is forbidden for agents, even for themselves", %{agent: agent} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.create_customer(attrs(agent), actor: agent)
    end
  end

  describe "reading" do
    test "humans see only customers of their own agents", ctx do
      mine = customer(ctx.agent)
      _theirs = customer(agent(ctx.other))

      assert [%{id: id}] = Revenue.list_customers!(actor: ctx.owner)
      assert id == mine.id
      assert {:error, %Ash.Error.Invalid{}} = Revenue.get_customer(mine.id, actor: ctx.other)
    end

    test "lists newest first", %{owner: owner, agent: agent} do
      first = customer(agent)
      second = customer(agent)

      assert Enum.map(Revenue.list_customers!(actor: owner), & &1.id) == [second.id, first.id]
    end

    test "returns nothing for a human without agents", %{other: other} do
      assert [] = Revenue.list_customers!(actor: other)
    end
  end

  describe "update_customer" do
    test "changes name and email", %{owner: owner, agent: agent} do
      customer = customer(agent)

      assert {:ok, updated} =
               Revenue.update_customer(customer, %{name: "New Name", email: "new@example.com"},
                 actor: owner
               )

      assert updated.name == "New Name"
      assert updated.email == "new@example.com"
      assert updated.agent_id == agent.id
    end

    test "cannot reassign ownership to another agent", %{owner: owner, agent: agent} do
      customer = customer(agent)
      second_agent = agent(owner)

      assert {:error, %Ash.Error.Invalid{}} =
               Revenue.update_customer(customer, %{agent_id: second_agent.id}, actor: owner)

      assert Revenue.get_customer!(customer.id, actor: owner).agent_id == agent.id
    end

    test "is forbidden for other humans", %{other: other, agent: agent} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.update_customer(customer(agent), %{name: "Hijacked"}, actor: other)
    end
  end

  describe "destroy_customer" do
    test "removes the owner's customer", %{owner: owner, agent: agent} do
      customer = customer(agent)

      assert :ok = Revenue.destroy_customer(customer, actor: owner)
      assert [] = Revenue.list_customers!(actor: owner)
    end

    test "is forbidden for other humans", %{other: other, agent: agent} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.destroy_customer(customer(agent), actor: other)
    end
  end
end
