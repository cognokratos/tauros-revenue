defmodule Tauros.Revenue.FinancialPayload do
  @moduledoc """
  The exact financial intent of an invoice revision, written in one canonical
  form, and its SHA-256 hash.

  A human approval authorizes one payload hash. If any value below changes,
  the hash changes, and the approval no longer describes what would be paid.

  ## Included: everything that decides who pays what, where and when

  | Field | Why |
  | --- | --- |
  | `schema` | version tag (`tauros.invoice.v1`); a new layout can never collide with an old hash |
  | `customer_id` | who is billed |
  | `currency` | what is owed |
  | `lines[].description`, `quantity`, `unit_amount` | what is billed, in order |
  | `total` | the amount authorized |
  | `destination.id`, `network`, `address` | where the money goes, spelled out even though destinations are immutable |
  | `due_date` | when it is owed |

  ## Excluded

  | Field | Why |
  | --- | --- |
  | timestamps, revision number, ids of the invoice or revision | metadata about the record, not the intent: an identical payload proposed again hashes the same |
  | agent reasoning | the explanation for the intent, not the intent; it is stored next to the revision |
  | customer name and email | reference data a human may correct without changing who is billed |
  | destination label | presentation |

  ## Canonical form

  JSON with keys sorted at every level and no whitespace. Decimals are written
  normalized (`"1.50"` and `"1.5"` are the same amount), dates as ISO 8601,
  identifiers as lowercase strings, and text in Unicode NFC. Line order is
  kept: an invoice is an ordered document.
  """

  @schema "tauros.invoice.v1"

  @doc """
  Returns `{canonical_json, sha256_hex}` for revision fields and the destination
  they name.
  """
  def seal(fields, destination) do
    json = exactly(fn -> fields |> build(destination) |> encode() end)
    {json, hash(json)}
  end

  @doc "The canonical map, before encoding."
  def build(fields, destination) do
    %{
      schema: @schema,
      customer_id: fields.customer_id,
      currency: fields.currency,
      due_date: fields.due_date,
      lines: Enum.map(fields.lines, &Map.take(&1, [:description, :quantity, :unit_amount])),
      total: total(fields.lines),
      destination: Map.take(destination, [:id, :network, :address])
    }
  end

  @doc "`quantity × unit_amount`, exactly."
  def line_amount(line), do: exactly(fn -> Decimal.mult(line.quantity, line.unit_amount) end)

  @doc "The sum of the line amounts, exactly."
  def total(lines) do
    exactly(fn ->
      Enum.reduce(lines, Decimal.new(0), &Decimal.add(&2, line_amount(&1)))
    end)
  end

  # Decimal's default context keeps 34 significant digits and rounds silently
  # beyond that, which an 18-decimal asset can reach. Financial arithmetic runs
  # with room to spare and traps `:inexact`, so a result is exact or an error.
  @exact %Decimal.Context{
    precision: 200,
    rounding: :half_even,
    traps: [:invalid_operation, :division_by_zero, :inexact]
  }

  @doc "Runs `fun` in a decimal context where any rounding raises."
  def exactly(fun), do: Decimal.Context.with(@exact, fun)

  @doc "Encodes a payload map canonically."
  def encode(payload), do: payload |> canonical() |> Jason.encode!()

  @doc "SHA-256 of the canonical JSON, lowercase hex."
  def hash(json), do: :sha256 |> :crypto.hash(json) |> Base.encode16(case: :lower)

  defp canonical(%Decimal{} = decimal),
    do: decimal |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp canonical(%Date{} = date), do: Date.to_iso8601(date)

  defp canonical(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(binary) when is_binary(binary), do: :unicode.characters_to_nfc_binary(binary)
  defp canonical(atom) when is_atom(atom) and not is_nil(atom), do: Atom.to_string(atom)
  defp canonical(other), do: other
end
