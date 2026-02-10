defmodule TaurosWeb.Api.Agent.AccountJSON do
  alias Tauros.Wallets.Account

  def render("show.json", %{account: account}) do
    %{data: data(account)}
  end

  defp data(%Account{} = account) do
    %{
      id: account.id,
      wallet_name: account.wallet_name,
      public_address: account.public_address,
      currency: account.currency,
      agent_id: account.agent_id,
      inserted_at: account.inserted_at,
      updated_at: account.updated_at
    }
  end
end
