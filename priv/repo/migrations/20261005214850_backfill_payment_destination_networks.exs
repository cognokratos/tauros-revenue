defmodule Tauros.Repo.Migrations.BackfillPaymentDestinationNetworks do
  @moduledoc """
  Data migration (hand-written; codegen only produces schema changes).

  Before this change a wallet account's currency implied its network: BTC was
  Bitcoin, fiat was a bank transfer to an IBAN, and Ether and ERC-20 tokens were
  Ethereum mainnet. This writes that implicit network down so the next
  migration can make `network` required. No information is invented.
  """
  use Ecto.Migration

  @fiat ~w(USD EUR CHF GBP JPY CAD AUD NZD SEK NOK DKK SGD)

  def up do
    execute """
    UPDATE payment_destinations
    SET network = CASE
      WHEN currency = 'BTC' THEN 'bitcoin'
      WHEN currency IN (#{Enum.map_join(@fiat, ", ", &"'#{&1}'")}) THEN 'iban'
      ELSE 'ethereum'
    END
    WHERE network IS NULL
    """
  end

  def down, do: :ok
end
