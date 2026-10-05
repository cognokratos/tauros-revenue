defmodule Tauros.Revenue.InvoiceRevision.Changes.Seal do
  @moduledoc """
  Numbers the revision and seals its financial payload: computes the total,
  the canonical JSON and its SHA-256 (`Tauros.Revenue.FinancialPayload`).

  None of these values is accepted from the caller.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Tauros.Revenue.{FinancialPayload, PaymentDestination}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      fields =
        Map.new(
          [:customer_id, :payment_destination_id, :currency, :due_date, :lines],
          &{&1, Ash.Changeset.get_attribute(changeset, &1)}
        )

      case Ash.get(PaymentDestination, fields.payment_destination_id,
             authorize?: false,
             error?: false
           ) do
        {:ok, %PaymentDestination{} = destination} when is_list(fields.lines) ->
          seal(changeset, fields, destination)

        # An unknown destination or missing lines are reported by validations.
        _ ->
          changeset
      end
    end)
  end

  defp seal(changeset, fields, destination) do
    {canonical, hash} = FinancialPayload.seal(fields, destination)

    Ash.Changeset.force_change_attributes(changeset,
      number: next_number(Ash.Changeset.get_attribute(changeset, :invoice_id)),
      total: FinancialPayload.total(fields.lines),
      canonical_payload: canonical,
      payload_hash: hash
    )
  end

  # The invoice row is locked by the calling action, so numbering cannot race;
  # the unique identity on (invoice_id, number) is the backstop.
  defp next_number(invoice_id) do
    Tauros.Revenue.InvoiceRevision
    |> Ash.Query.filter(invoice_id == ^invoice_id)
    |> Ash.max!(:number, authorize?: false)
    |> case do
      nil -> 1
      number -> number + 1
    end
  end
end
