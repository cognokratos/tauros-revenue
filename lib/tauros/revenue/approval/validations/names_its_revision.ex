defmodule Tauros.Revenue.Approval.Validations.NamesItsRevision do
  @moduledoc """
  An approval must name a revision of its own invoice, and that revision's
  exact payload hash. `Invoice.Changes.Decide` already guarantees this; the
  resource checks it again so no other code path can write an approval that
  points at the wrong payload.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    invoice_id = Ash.Changeset.get_attribute(changeset, :invoice_id)
    hash = Ash.Changeset.get_attribute(changeset, :payload_hash)

    case Ash.get(
           Tauros.Revenue.InvoiceRevision,
           Ash.Changeset.get_attribute(changeset, :revision_id),
           authorize?: false,
           error?: false
         ) do
      {:ok, %{invoice_id: ^invoice_id, payload_hash: ^hash}} -> :ok
      _ -> {:error, field: :payload_hash, message: "does not match the named revision"}
    end
  end
end
