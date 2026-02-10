defmodule Tauros.WalletsTest do
  use Tauros.DataCase

  import Tauros.AgentsFixtures
  import Tauros.WalletsFixtures

  alias Tauros.Wallets
  alias Tauros.Wallets.Account

  describe "create_account/2" do
    test "creates account with valid data" do
      agent = agent_fixture()

      attrs = %{
        "wallet_name" => "My Wallet",
        "public_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "currency" => "USD"
      }

      assert {:ok, %Account{} = account} = Wallets.create_account(agent, attrs)
      assert account.wallet_name == "My Wallet"
      assert account.public_address == "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      assert account.currency == "USD"
      assert account.agent_id == agent.id
    end

    test "returns error when wallet_name is missing" do
      agent = agent_fixture()

      attrs = %{
        "public_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "currency" => "USD"
      }

      assert {:error, changeset} = Wallets.create_account(agent, attrs)
      assert :wallet_name in Enum.map(changeset.errors, &elem(&1, 0))
    end

    test "returns error when public_address is missing" do
      agent = agent_fixture()

      attrs = %{
        "wallet_name" => "My Wallet",
        "currency" => "USD"
      }

      assert {:error, changeset} = Wallets.create_account(agent, attrs)
      assert :public_address in Enum.map(changeset.errors, &elem(&1, 0))
    end

    test "returns error when currency is missing" do
      agent = agent_fixture()

      attrs = %{
        "wallet_name" => "My Wallet",
        "public_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }

      assert {:error, changeset} = Wallets.create_account(agent, attrs)
      assert :currency in Enum.map(changeset.errors, &elem(&1, 0))
    end

    test "validates public_address format" do
      agent = agent_fixture()

      attrs = %{
        "wallet_name" => "My Wallet",
        "public_address" => "invalid_address",
        "currency" => "USD"
      }

      assert {:error, changeset} = Wallets.create_account(agent, attrs)
      assert :public_address in Enum.map(changeset.errors, &elem(&1, 0))
    end

    test "automatically sets agent_id from provided agent" do
      agent = agent_fixture()

      attrs = %{
        "wallet_name" => "My Wallet",
        "public_address" => "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "currency" => "USD"
      }

      {:ok, account} = Wallets.create_account(agent, attrs)
      assert account.agent_id == agent.id
    end
  end

  describe "list_accounts_for_agent/1" do
    test "lists all accounts for an agent" do
      agent = agent_fixture()
      account1 = account_fixture(agent)
      account2 = account_fixture(agent)

      accounts = Wallets.list_accounts_for_agent(agent)
      assert length(accounts) == 2
      assert account1.id in Enum.map(accounts, & &1.id)
      assert account2.id in Enum.map(accounts, & &1.id)
    end

    test "lists only accounts scoped to that agent" do
      agent1 = agent_fixture()
      agent2 = agent_fixture()

      account1 = account_fixture(agent1)
      account2 = account_fixture(agent2)

      accounts = Wallets.list_accounts_for_agent(agent1)
      assert length(accounts) == 1
      assert account1.id in Enum.map(accounts, & &1.id)
      refute account2.id in Enum.map(accounts, & &1.id)
    end

    test "returns empty list when agent has no accounts" do
      agent = agent_fixture()

      accounts = Wallets.list_accounts_for_agent(agent)
      assert accounts == []
    end
  end

  describe "get_account!/2" do
    test "gets an account by id for an agent" do
      agent = agent_fixture()
      account = account_fixture(agent)

      retrieved = Wallets.get_account!(agent, account.id)
      assert retrieved.id == account.id
      assert retrieved.agent_id == agent.id
    end

    test "raises NoResultsError when account doesn't belong to agent" do
      agent1 = agent_fixture()
      agent2 = agent_fixture()
      account = account_fixture(agent1)

      assert_raise Ecto.NoResultsError, fn ->
        Wallets.get_account!(agent2, account.id)
      end
    end

    test "raises NoResultsError when account doesn't exist" do
      agent = agent_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Wallets.get_account!(agent, Ecto.UUID.generate())
      end
    end
  end

  describe "change_account/2" do
    test "returns changeset for account" do
      account = account_fixture()

      changeset = Wallets.change_account(account)
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == account
    end

    test "includes changes when attrs provided" do
      account = account_fixture()
      new_attrs = %{wallet_name: "Updated Name"}

      changeset = Wallets.change_account(account, new_attrs)
      assert changeset.changes == new_attrs
    end
  end
end
