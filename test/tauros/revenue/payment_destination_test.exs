defmodule Tauros.Revenue.PaymentDestinationTest do
  use Tauros.DataCase, async: true

  alias Tauros.Revenue
  alias Tauros.Revenue.Network

  @evm "0x1234567890123456789012345678901234567890"
  @taproot "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr"
  @iban "CH9300762011623852957"

  setup do
    owner = user()
    %{owner: owner, agent: agent(owner)}
  end

  defp create(agent, attrs) do
    %{label: "Treasury", currency: "USDC", network: "ethereum", address: @evm}
    |> Map.merge(attrs)
    |> Revenue.create_payment_destination(actor: agent)
  end

  defp error_fields({:error, %Ash.Error.Invalid{errors: errors}}),
    do: errors |> Enum.map(& &1.field) |> Enum.sort()

  describe "create_payment_destination" do
    test "is registered by an agent and scoped to it", %{agent: agent} do
      assert {:ok, destination} = create(agent, %{})
      assert destination.label == "Treasury"
      assert {destination.currency, destination.network} == {:USDC, :ethereum}
      assert destination.address == @evm
      assert destination.agent_id == agent.id
    end

    test "ignores any attempt to register on behalf of another agent", %{
      owner: owner,
      agent: agent
    } do
      assert {:error, %Ash.Error.Invalid{}} = create(agent, %{agent_id: agent(owner).id})
    end

    test "requires label, currency, network and address", %{agent: agent} do
      result = Revenue.create_payment_destination(%{}, actor: agent)
      assert error_fields(result) == [:address, :currency, :label, :network]
    end

    test "is forbidden for humans and anonymous callers", %{owner: owner} do
      attrs = %{label: "Treasury", currency: "USDC", network: "ethereum", address: @evm}

      assert {:error, %Ash.Error.Forbidden{}} =
               Revenue.create_payment_destination(attrs, actor: owner)

      assert {:error, _} = Revenue.create_payment_destination(attrs)
    end
  end

  describe "a currency does not decide the settlement network" do
    test "the same currency can be received on several networks", %{agent: agent} do
      for network <- ["ethereum", "arbitrum", "base"] do
        assert {:ok, destination} = create(agent, %{currency: "USDC", network: network})
        assert destination.network == String.to_existing_atom(network)
      end

      assert Network.for_currency(:USDC) == [:ethereum, :arbitrum, :base]
    end

    test "different currencies share a network and its address format", %{agent: agent} do
      assert {:ok, eth} = create(agent, %{currency: "ETH", network: "arbitrum"})
      assert {:ok, usdc} = create(agent, %{currency: "USDC", network: "arbitrum"})
      assert Network.rail(eth.network) == Network.rail(usdc.network)
    end

    test "fiat currencies all arrive by bank transfer, not by an implied rail", %{agent: agent} do
      assert {:ok, chf} = create(agent, %{currency: "CHF", network: "iban", address: @iban})
      assert Network.rail(chf.network) == :bank_transfer
      assert Network.for_currency(:EUR) == [:iban]
    end

    test "a network that does not carry the currency is rejected", %{agent: agent} do
      assert error_fields(create(agent, %{currency: "BTC", network: "ethereum"})) == [:network]
      assert error_fields(create(agent, %{currency: "EUR", network: "base"})) == [:network]
      assert error_fields(create(agent, %{currency: "USDC", network: "bitcoin"})) == [:network]
    end

    test "unsupported currencies and networks are rejected", %{agent: agent} do
      assert error_fields(create(agent, %{currency: "DOGE"})) == [:currency]
      assert error_fields(create(agent, %{network: "solana"})) == [:network]
    end
  end

  describe "address format is decided by the network's rail" do
    test "Bitcoin requires a Taproot address", %{agent: agent} do
      assert {:ok, _} = create(agent, %{currency: "BTC", network: "bitcoin", address: @taproot})

      assert error_fields(create(agent, %{currency: "BTC", network: "bitcoin", address: @evm})) ==
               [:address]
    end

    test "every EVM network requires an EVM address", %{agent: agent} do
      for network <- ["ethereum", "arbitrum", "base"] do
        assert error_fields(create(agent, %{network: network, address: "0x123"})) == [:address]
      end
    end

    test "bank transfers require an IBAN", %{agent: agent} do
      assert error_fields(create(agent, %{currency: "EUR", network: "iban", address: @evm})) ==
               [:address]
    end
  end

  describe "checksums catch typos that the format alone would accept" do
    test "a Taproot address with one wrong character is rejected", %{agent: agent} do
      typo = String.replace_suffix(@taproot, "r", "s")
      assert typo =~ ~r/^bc1p[a-z0-9]{58}$/

      assert error_fields(create(agent, %{currency: "BTC", network: "bitcoin", address: typo})) ==
               [:address]
    end

    test "only Taproot (witness v1, 32 bytes) is accepted on Bitcoin", %{agent: agent} do
      segwit_v0 = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

      assert error_fields(
               create(agent, %{currency: "BTC", network: "bitcoin", address: segwit_v0})
             ) == [:address]
    end

    test "an IBAN with one wrong digit is rejected", %{agent: agent} do
      typo = "CH9300762011623852958"

      assert error_fields(create(agent, %{currency: "CHF", network: "iban", address: typo})) ==
               [:address]
    end

    test "EVM addresses are format-checked only: EIP-55 casing is not verified", %{agent: agent} do
      # A deliberately documented limit (see Tauros.Revenue.Address): verifying
      # EIP-55 needs Keccak-256, which core Erlang does not provide.
      wrongly_cased = "0x1234567890ABCDEF1234567890abcdef12345678"
      assert {:ok, _} = create(agent, %{address: wrongly_cased})
    end
  end

  describe "reading" do
    test "humans see the destinations of all their agents, and only theirs", ctx do
      mine = [payment_destination(ctx.agent), payment_destination(agent(ctx.owner))]
      _theirs = payment_destination(agent(user()))

      assert ctx.owner |> list_ids() |> Enum.sort() == mine |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "agents see only their own destinations", %{owner: owner, agent: agent} do
      mine = payment_destination(agent)
      _sibling = payment_destination(agent(owner))

      assert list_ids(agent) == [mine.id]
    end
  end

  defp list_ids(actor), do: Enum.map(Revenue.list_payment_destinations!(actor: actor), & &1.id)
end
