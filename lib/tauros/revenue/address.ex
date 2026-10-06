defmodule Tauros.Revenue.Address do
  @moduledoc """
  Receiving-address rules per settlement rail (see `Tauros.Revenue.Network.rail/1`).

  A wrong character in a payment destination sends money somewhere nobody can
  recover it from. Where an address scheme carries a checksum that core Erlang
  can verify, Tauros verifies it; otherwise it checks the format and says so.

  | Rail | What is checked | What is not |
  | --- | --- | --- |
  | `:bitcoin` | Taproot only: `bc1p`, bech32m checksum (BIP-350), 32-byte witness program | other address types, testnets, whether the key is spendable |
  | `:evm` | **format only**: `0x` and 40 hex characters | the EIP-55 mixed-case checksum (it needs Keccak-256, which OTP's `:crypto` does not provide), whether the address is a contract |
  | `:bank_transfer` | IBAN: country code, length, ISO 13616 mod-97 checksum | country-specific length and BBAN structure, whether the account exists |

  None of these checks prove that anyone controls the address. That is why a
  destination is shown to a human before any invoice that uses it is approved.
  """

  import Bitwise

  @doc "Returns `:ok` or `{:error, message}` for `address` on `rail`."
  def validate(:bitcoin, address) do
    if taproot?(address),
      do: :ok,
      else: {:error, "must be a Taproot Bitcoin address (bc1p…) with a valid checksum"}
  end

  def validate(:evm, address) do
    if address =~ ~r/^0x[a-fA-F0-9]{40}$/,
      do: :ok,
      else: {:error, "must be an EVM address (0x followed by 40 hex characters)"}
  end

  def validate(:bank_transfer, address) do
    if iban?(address),
      do: :ok,
      else: {:error, "must be an IBAN in electronic format (no spaces) with a valid checksum"}
  end

  ## IBAN (ISO 13616): move the first four characters to the end, replace each
  ## letter with two digits (A = 10 … Z = 35); the number mod 97 must be 1.

  defp iban?(iban) do
    iban =~ ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/ and
      (String.slice(iban, 4..-1//1) <> String.slice(iban, 0, 4))
      |> String.to_charlist()
      |> Enum.map_join(&iban_digits/1)
      |> String.to_integer()
      |> rem(97) == 1
  end

  defp iban_digits(char) when char in ?0..?9, do: <<char>>
  defp iban_digits(char), do: Integer.to_string(char - ?A + 10)

  ## Taproot (BIP-341) addresses are bech32m (BIP-350): human-readable part
  ## "bc", witness version 1 (the "p"), a 32-byte program and a 6-character
  ## checksum.

  @charset ~c"qpzry9x8gf2tvdw0s3jn54khce6mua7l"
  @bech32m_const 0x2BC830A3
  @generator [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]

  defp taproot?("bc1" <> data) when byte_size(data) == 59 do
    with {:ok, [1 | values]} <- decode_charset(data),
         true <- polymod(hrp_expand(~c"bc") ++ [1 | values]) == @bech32m_const,
         {:ok, program} <- from_5_bits(Enum.drop(values, -6)) do
      byte_size(program) == 32
    else
      _ -> false
    end
  end

  defp taproot?(_address), do: false

  defp decode_charset(data) do
    values = for <<char <- data>>, do: Enum.find_index(@charset, &(&1 == char))
    if nil in values, do: :error, else: {:ok, values}
  end

  defp hrp_expand(hrp), do: Enum.map(hrp, &(&1 >>> 5)) ++ [0] ++ Enum.map(hrp, &(&1 &&& 31))

  defp polymod(values) do
    Enum.reduce(values, 1, fn value, checksum ->
      top = checksum >>> 25

      @generator
      |> Enum.with_index()
      |> Enum.reduce(bxor((checksum &&& 0x1FFFFFF) <<< 5, value), &mix_generator(&1, &2, top))
    end)
  end

  defp mix_generator({generator, i}, acc, top),
    do: if((top >>> i &&& 1) == 1, do: bxor(acc, generator), else: acc)

  # Regroups 5-bit values into bytes; leftover padding bits must be zero.
  defp from_5_bits(values) do
    {bytes, acc, bits} =
      Enum.reduce(values, {<<>>, 0, 0}, fn value, {bytes, acc, bits} ->
        acc = (acc <<< 5 ||| value) &&& 0xFFF
        bits = bits + 5

        if bits >= 8,
          do: {<<bytes::binary, acc >>> (bits - 8) &&& 0xFF>>, acc, bits - 8},
          else: {bytes, acc, bits}
      end)

    if bits < 5 and (acc <<< (8 - bits) &&& 0xFF) == 0, do: {:ok, bytes}, else: :error
  end
end
