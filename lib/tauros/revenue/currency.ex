defmodule Tauros.Revenue.Currency do
  @moduledoc """
  What a customer owes: a fiat currency or a crypto asset.

  A currency does not decide how it is settled. USDC can arrive on several
  networks, and fiat can arrive at any bank. The network a payment uses is a
  property of the payment destination (`Tauros.Revenue.Network`).

  Each currency has a number of decimal places. Tauros never rounds money
  implicitly, so an amount with more decimals than its currency allows is
  rejected rather than rounded.
  """

  @crypto [
    :BTC,
    :ETH,
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
  @fiat [:USD, :EUR, :CHF, :GBP, :JPY, :CAD, :AUD, :NZD, :SEK, :NOK, :DKK, :SGD]

  use Ash.Type.Enum, values: @crypto ++ @fiat

  # Smallest unit: satoshi (8), wei (18), token decimals (mostly 18, USDT/USDC 6,
  # GUSD 2) and ISO 4217 minor units for fiat.
  @decimals %{
    BTC: 8,
    ETH: 18,
    USDT: 6,
    USDC: 6,
    DAI: 18,
    TUSD: 18,
    BUSD: 18,
    FDUSD: 18,
    GUSD: 2,
    PAX: 18,
    USDP: 18,
    LUSD: 18,
    FRAX: 18,
    SUSD: 18,
    JPY: 0
  }

  @doc "Crypto assets."
  def crypto, do: @crypto

  @doc "Fiat currencies, settled by bank transfer."
  def fiat, do: @fiat

  @doc "How many decimal places an amount in `currency` may have."
  def decimals(currency), do: Map.get(@decimals, currency, 2)
end
