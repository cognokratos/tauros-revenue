defmodule Tauros.Revenue.InvoiceRevision.Validations.AmountsFitCurrency do
  @moduledoc """
  Every unit amount and line amount must be payable in the currency's smallest
  unit, and the total must be positive.

  Tauros never rounds money implicitly. `1.005 EUR` is rejected rather than
  rounded, because a rounding rule is a financial decision a human should
  make, not something a library does in the background.
  """
  use Ash.Resource.Validation

  alias Tauros.Revenue.{Currency, FinancialPayload}

  @impl true
  def validate(changeset, _opts, _context) do
    currency = Ash.Changeset.get_attribute(changeset, :currency)
    lines = Ash.Changeset.get_attribute(changeset, :lines)

    if is_nil(currency) or lines in [nil, []] do
      :ok
    else
      check(lines, currency)
    end
  end

  defp check(lines, currency) do
    decimals = Currency.decimals(currency)

    lines
    |> Enum.with_index(1)
    |> Enum.find_value(fn {line, number} ->
      amount = Decimal.mult(line.quantity, line.unit_amount)

      cond do
        scale(line.unit_amount) > decimals -> too_precise(number, line.unit_amount, currency)
        scale(amount) > decimals -> too_precise(number, amount, currency)
        true -> nil
      end
    end)
    |> case do
      nil -> positive_total(lines)
      error -> error
    end
  end

  defp positive_total(lines) do
    if Decimal.gt?(FinancialPayload.total(lines), 0),
      do: :ok,
      else: {:error, field: :lines, message: "must add up to more than zero"}
  end

  defp too_precise(number, amount, currency) do
    {:error,
     field: :lines,
     message:
       "line #{number}: #{Decimal.to_string(amount, :normal)} has more decimal places than " <>
         "#{currency} allows (#{Currency.decimals(currency)}); Tauros never rounds money"}
  end

  defp scale(decimal) do
    case Decimal.normalize(decimal) do
      %Decimal{exp: exp} when exp < 0 -> -exp
      _ -> 0
    end
  end
end
