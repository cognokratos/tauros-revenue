defmodule Tauros.Revenue.Network do
  @moduledoc """
  Where a payment travels: a blockchain network or a bank account scheme.

  A currency alone says nothing about settlement. USDC exists on Ethereum,
  Arbitrum and Base; CHF and EUR both arrive by bank transfer to an IBAN. So
  every payment destination names its network, and the network decides:

    * the **rail** it belongs to (`:bitcoin`, `:evm`, `:bank_transfer`), which
      decides what a receiving address looks like (`Tauros.Revenue.Address`)
    * the **currencies** it can carry

  ```text
  currency  network    rail           address
  USDC      ethereum   evm            0x…
  USDC      arbitrum   evm            0x…
  ETH       base       evm            0x…
  BTC       bitcoin    bitcoin        bc1p…
  CHF       iban       bank_transfer  CH…
  ```

  A currency symbol is not a token contract. "USDC on Arbitrum" can mean
  native USDC or bridged USDC.e. Tauros records intent, not execution, so it
  stops at the symbol; a settlement adapter (Epic 6) must map symbol and
  network to a contract before it watches for payments.
  """

  use Ash.Type.Enum,
    values: [
      bitcoin: "Bitcoin mainnet",
      ethereum: "Ethereum mainnet",
      arbitrum: "Arbitrum One",
      base: "Base mainnet",
      iban: "Bank transfer to an IBAN"
    ]

  @erc20_stablecoins [
    :USDT,
    :USDC,
    :DAI,
    :TUSD,
    :BUSD,
    :FDUSD,
    :GUSD,
    :PAX,
    :USDP,
    :LUSD,
    :FRAX,
    :SUSD
  ]

  @currencies %{
    bitcoin: [:BTC],
    ethereum: [:ETH | @erc20_stablecoins],
    arbitrum: [:ETH, :USDC, :USDT, :DAI],
    base: [:ETH, :USDC, :DAI],
    iban: Tauros.Revenue.Currency.fiat()
  }

  @rails %{
    bitcoin: :bitcoin,
    ethereum: :evm,
    arbitrum: :evm,
    base: :evm,
    iban: :bank_transfer
  }

  @doc "The settlement rail of a network. The rail decides the address format."
  def rail(network), do: Map.fetch!(@rails, network)

  @doc "The currencies a network can carry."
  def currencies(network), do: Map.fetch!(@currencies, network)

  @doc "Whether `currency` can be received on `network`."
  def carries?(network, currency), do: currency in currencies(network)

  @doc "The networks that can carry `currency`."
  def for_currency(currency),
    do: for(network <- values(), carries?(network, currency), do: network)

  @doc "A short human label, e.g. \"Arbitrum One\"."
  def label(network), do: description(network)
end
