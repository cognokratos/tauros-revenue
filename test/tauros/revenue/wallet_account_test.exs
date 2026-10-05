defmodule Tauros.Revenue.WalletAccountTest do
  use Tauros.DataCase, async: true

  alias Tauros.Revenue

  @eth "0x1234567890123456789012345678901234567890"
  @taproot "bc1pxy2kgdygjrsqtzq2n0yrf2493p3xcn65v4ezuqpf9eajsuu4k4uqjc37h0"
  @iban "CH9300762011623852957"

  setup do
    owner = user()
    %{owner: owner, agent: agent(owner)}
  end

  defp create(agent, attrs) do
    %{wallet_name: "Treasury", public_address: @eth, currency: "ETH"}
    |> Map.merge(attrs)
    |> Revenue.create_wallet_account(actor: agent)
  end

  defp error_fields({:error, %Ash.Error.Invalid{errors: errors}}),
    do: errors |> Enum.map(& &1.field) |> Enum.sort()

  describe "create_wallet_account" do
    test "is registered by an agent and scoped to it", %{agent: agent} do
      assert {:ok, account} = create(agent, %{})
      assert account.wallet_name == "Treasury"
      assert account.public_address == @eth
      assert account.currency == :ETH
      assert account.agent_id == agent.id
    end

    test "ignores any attempt to register on behalf of another agent", %{
      owner: owner,
      agent: agent
    } do
      other_agent = agent(owner)

      assert {:error, %Ash.Error.Invalid{}} = create(agent, %{agent_id: other_agent.id})
    end

    test "requires wallet name, public address and currency", %{agent: agent} do
      assert {:error, _} =
               result = Revenue.create_wallet_account(%{}, actor: agent)

      assert error_fields(result) == [:currency, :public_address, :wallet_name]
    end

    test "is forbidden for humans and anonymous callers", %{owner: owner} do
      attrs = %{wallet_name: "Treasury", public_address: @eth, currency: "ETH"}

      assert {:error, %Ash.Error.Forbidden{}} = Revenue.create_wallet_account(attrs, actor: owner)
      assert {:error, _} = Revenue.create_wallet_account(attrs)
    end
  end

  describe "public address validation by settlement rail" do
    test "Bitcoin requires a Taproot address", %{agent: agent} do
      assert {:ok, _} = create(agent, %{currency: "BTC", public_address: @taproot})

      assert error_fields(create(agent, %{currency: "BTC", public_address: @eth})) ==
               [:public_address]
    end

    test "Ether and stablecoins require an Ethereum address", %{agent: agent} do
      assert {:ok, _} = create(agent, %{currency: "USDC", public_address: @eth})

      assert error_fields(create(agent, %{currency: "ETH", public_address: "0x123"})) ==
               [:public_address]
    end

    test "fiat currencies require an IBAN", %{agent: agent} do
      assert {:ok, _} = create(agent, %{currency: "CHF", public_address: @iban})

      assert error_fields(create(agent, %{currency: "EUR", public_address: @eth})) ==
               [:public_address]
    end

    test "unsupported currencies are rejected", %{agent: agent} do
      assert error_fields(create(agent, %{currency: "DOGE"})) == [:currency]
    end
  end

  describe "reading" do
    test "humans see the wallet accounts of all their agents, and only theirs", ctx do
      mine = [wallet_account(ctx.agent), wallet_account(agent(ctx.owner))]
      _theirs = wallet_account(agent(user()))

      assert ctx.owner |> list_ids() |> Enum.sort() == mine |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "agents see only their own wallet accounts", %{owner: owner, agent: agent} do
      mine = wallet_account(agent)
      _sibling = wallet_account(agent(owner))

      assert list_ids(agent) == [mine.id]
    end
  end

  defp list_ids(actor), do: Enum.map(Revenue.list_wallet_accounts!(actor: actor), & &1.id)
end
