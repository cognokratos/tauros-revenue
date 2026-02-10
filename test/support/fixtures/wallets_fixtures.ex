defmodule Tauros.WalletsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tauros.Wallets` context.
  """

  import Tauros.AgentsFixtures

  @doc """
  Generate an account fixture for a given agent.
  """
  def account_fixture(agent \\ nil, attrs \\ %{}) do
    agent = agent || agent_fixture()

    attrs =
      Enum.into(attrs, %{
        "currency" => "USD",
        "public_address" => "0x1234567890123456789012345678901234567890",
        "wallet_name" => "Test Wallet"
      })

    {:ok, account} = Tauros.Wallets.create_account(agent, attrs)
    account
  end
end
