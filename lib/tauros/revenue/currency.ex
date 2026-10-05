defmodule Tauros.Revenue.Currency do
  @moduledoc """
  Currencies Tauros can receive, grouped by the settlement rail that
  determines what a valid receiving address looks like.
  """

  @bitcoin [:BTC]
  @ethereum [
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

  use Ash.Type.Enum, values: @bitcoin ++ @ethereum ++ @fiat

  @doc "Settled on Bitcoin; receiving addresses must be Taproot (`bc1p…`)."
  def bitcoin, do: @bitcoin

  @doc "Ether and ERC-20 stablecoins; receiving addresses are `0x` + 40 hex characters."
  def ethereum, do: @ethereum

  @doc "Fiat currencies settled by bank transfer; receiving addresses are IBANs."
  def fiat, do: @fiat
end
