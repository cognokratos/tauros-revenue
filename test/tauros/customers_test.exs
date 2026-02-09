defmodule Tauros.CustomersTest do
  use Tauros.DataCase

  alias Tauros.Customers
  alias Tauros.Accounts.Scope
  import Tauros.AccountsFixtures
  import Tauros.AgentsFixtures
  import Tauros.CustomersFixtures

  describe "create_customer/2" do
    test "creates a customer and associates it to the given agent" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      scope = %Scope{user: user}

      assert {:ok, customer} =
               Customers.create_customer(scope, %{
                 "name" => "ACME Inc",
                 "email" => "contact@acme.com",
                 "agent_id" => agent.id
               })

      assert customer.name == "ACME Inc"
      assert customer.email == "contact@acme.com"
      assert customer.agent_id == agent.id
    end

    test "returns error when required fields are missing" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      scope = %Scope{user: user}

      assert {:error, changeset} =
               Customers.create_customer(scope, %{
                 "name" => "ACME Inc",
                 "agent_id" => agent.id
               })

      assert :email in Keyword.keys(changeset.errors)
    end

    test "rejects customer creation for agent not owned by user" do
      user1 = user_fixture()
      user2 = user_fixture()
      agent = agent_fixture(%{user_id: user2.id})
      scope = %Scope{user: user1}

      assert {:error, msg} =
               Customers.create_customer(scope, %{
                 "name" => "ACME Inc",
                 "email" => "contact@acme.com",
                 "agent_id" => agent.id
               })

      assert is_binary(msg)
    end
  end

  describe "list_customers/1" do
    test "lists only customers for the user's agents" do
      user = user_fixture()
      other_user = user_fixture()
      user_agent = agent_fixture(%{user_id: user.id})
      other_agent = agent_fixture(%{user_id: other_user.id})

      user_customer = customer_fixture(%{"agent_id" => user_agent.id})
      _other_customer = customer_fixture(%{"agent_id" => other_agent.id})

      scope = %Scope{user: user}
      customers = Customers.list_customers(scope)

      assert length(customers) == 1
      assert Enum.any?(customers, &(&1.id == user_customer.id))
    end

    test "returns empty list when user has no agents" do
      user = user_fixture()
      scope = %Scope{user: user}

      customers = Customers.list_customers(scope)
      assert customers == []
    end
  end

  describe "get_customer!/2" do
    test "returns a customer owned by the user" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      scope = %Scope{user: user}

      found = Customers.get_customer!(scope, customer.id)
      assert found.id == customer.id
    end

    test "raises when customer doesn't belong to user's agent" do
      user = user_fixture()
      other_user = user_fixture()
      other_agent = agent_fixture(%{user_id: other_user.id})
      customer = customer_fixture(%{"agent_id" => other_agent.id})
      scope = %Scope{user: user}

      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(scope, customer.id)
      end
    end
  end

  describe "update_customer/3" do
    test "updates a customer" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      scope = %Scope{user: user}

      assert {:ok, updated} =
               Customers.update_customer(scope, customer, %{
                 "name" => "Updated Name"
               })

      assert updated.name == "Updated Name"
    end

    test "raises when customer doesn't belong to user" do
      user = user_fixture()
      other_user = user_fixture()
      other_agent = agent_fixture(%{user_id: other_user.id})
      customer = customer_fixture(%{"agent_id" => other_agent.id})
      scope = %Scope{user: user}

      assert_raise Ecto.NoResultsError, fn ->
        Customers.update_customer(scope, customer, %{"name" => "Updated"})
      end
    end
  end

  describe "delete_customer/2" do
    test "deletes a customer" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      scope = %Scope{user: user}

      assert {:ok, _} = Customers.delete_customer(scope, customer)

      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(scope, customer.id)
      end
    end

    test "raises when customer doesn't belong to user" do
      user = user_fixture()
      other_user = user_fixture()
      other_agent = agent_fixture(%{user_id: other_user.id})
      customer = customer_fixture(%{"agent_id" => other_agent.id})
      scope = %Scope{user: user}

      assert_raise Ecto.NoResultsError, fn ->
        Customers.delete_customer(scope, customer)
      end
    end
  end

  describe "update_customer/3 - ownership enforcement" do
    test "rejects agent_id reassignment on update" do
      user = user_fixture()
      agent1 = agent_fixture(%{user_id: user.id})
      agent2 = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent1.id})
      scope = %Scope{user: user}

      assert {:error, changeset} =
               Customers.update_customer(scope, customer, %{
                 "agent_id" => agent2.id
               })

      assert :agent_id in Keyword.keys(changeset.errors)
    end

    test "allows update of name without agent_id" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      scope = %Scope{user: user}

      assert {:ok, updated} =
               Customers.update_customer(scope, customer, %{
                 "name" => "New Name"
               })

      assert updated.name == "New Name"
      assert updated.agent_id == agent.id
    end

    test "allows email update without agent_id" do
      user = user_fixture()
      agent = agent_fixture(%{user_id: user.id})
      customer = customer_fixture(%{"agent_id" => agent.id})
      scope = %Scope{user: user}

      assert {:ok, updated} =
               Customers.update_customer(scope, customer, %{
                 "email" => "newemail@example.com"
               })

      assert updated.email == "newemail@example.com"
      assert updated.agent_id == agent.id
    end
  end
end
