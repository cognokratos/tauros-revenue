defmodule Tauros.Revenue.Address do
  @moduledoc """
  Receiving-address rules per settlement rail (see `Tauros.Revenue.Network.rail/1`).

  These are **format** checks: they verify the shape of an address, not that
  anyone controls it.
  """

  @doc "Returns `:ok` or `{:error, message}` for `address` on `rail`."
  def validate(:bitcoin, address) do
    if address =~ ~r/^bc1p[a-z0-9]{38,60}$/,
      do: :ok,
      else: {:error, "must be a Taproot Bitcoin address (bc1p…)"}
  end

  def validate(:evm, address) do
    if address =~ ~r/^0x[a-fA-F0-9]{40}$/,
      do: :ok,
      else: {:error, "must be an EVM address (0x followed by 40 hex characters)"}
  end

  def validate(:bank_transfer, address) do
    if address =~ ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/,
      do: :ok,
      else: {:error, "must be an IBAN in electronic format (no spaces)"}
  end
end
