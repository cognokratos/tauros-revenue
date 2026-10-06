defmodule Tauros.Revenue.Invoice.Changes.Decide do
  @moduledoc """
  Records a human decision about one exact revision, and moves the invoice.

  The approver must name what they decide on: `revision_id` and
  `payload_hash`. Inside the transaction, with the invoice row locked:

  1. **Replay.** If this revision already has a decision by the same approver
     with the same outcome and hash, nothing is written and the call
     succeeds. Any other existing decision is a 409 `already_decided`.
  2. **State machine.** The transition is checked against the locked row
     (`pending_approval` only).
  3. **Exactness.** The named revision must be the current one (409
     `stale_revision`) and the hash must be its hash (409
     `payload_mismatch`). The stored payload is re-sealed from the revision's
     fields; if it does not reproduce the stored hash the revision was altered
     outside Tauros and nothing is approved (409 `payload_integrity`).
  4. **Destination.** To approve, the destination row is locked and must
     still be active, so a destination cannot be deactivated half-way through
     an approval. A retired destination forces a new revision and a new review.
  5. The `Approval` is created through `manage_relationship`, the only path
     its create policy allows.

  ## Options

    * `:decision` – `:approved`, `:rejected` or `:changes_requested`
    * `:to` – the invoice state the decision leads to
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Tauros.Revenue.{Approval, FinancialPayload, InvoiceRevision, PaymentDestination}
  alias Tauros.Revenue.Errors.Conflict

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case lock(changeset.resource, changeset.data.id) do
        {:ok, invoice} -> decide(%{changeset | data: invoice}, opts, context.actor)
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end

  defp decide(changeset, opts, actor) do
    revision_id = Ash.Changeset.get_argument(changeset, :revision_id)
    hash = Ash.Changeset.get_argument(changeset, :payload_hash)

    case existing_decision(changeset.data.id, revision_id) do
      %Approval{} = decision ->
        replay_or_conflict(changeset, decision, opts, hash, actor)

      nil ->
        changeset
        |> AshStateMachine.transition_state(opts[:to])
        |> record(opts, revision_id, hash)
    end
  end

  defp replay_or_conflict(changeset, decision, opts, hash, actor) do
    if decision.decision == opts[:decision] and decision.payload_hash == hash and
         decision.approver_id == actor.id do
      changeset
      |> Ash.Changeset.set_context(%{replay?: true})
      |> Ash.Changeset.set_result({:ok, changeset.data})
    else
      conflict(
        changeset,
        :already_decided,
        :revision_id,
        "was already decided (#{decision.decision}); a new decision needs a new revision"
      )
    end
  end

  defp record(%{valid?: false} = changeset, _opts, _revision_id, _hash), do: changeset

  defp record(changeset, opts, revision_id, hash) do
    revision = current_revision(changeset.data.id)

    with :ok <- current?(revision, revision_id),
         :ok <- same_hash?(revision, hash),
         {:ok, destination} <- lock(PaymentDestination, revision.payment_destination_id),
         :ok <- sealed?(revision, destination),
         :ok <- usable?(destination, opts[:decision]) do
      Ash.Changeset.manage_relationship(
        changeset,
        :approvals,
        [
          %{
            revision_id: revision.id,
            payload_hash: revision.payload_hash,
            decision: opts[:decision],
            reason: Ash.Changeset.get_argument(changeset, :reason)
          }
        ],
        type: :create
      )
    else
      {code, field, message} -> conflict(changeset, code, field, message)
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
    end
  end

  defp current?(%{id: id}, id), do: :ok

  defp current?(revision, _stale),
    do:
      {:stale_revision, :revision_id,
       "is not the current revision (revision #{revision.number} is); review that one"}

  defp same_hash?(%{payload_hash: hash}, hash), do: :ok

  defp same_hash?(_revision, _hash),
    do: {:payload_mismatch, :payload_hash, "does not match the current revision's payload"}

  defp sealed?(revision, destination) do
    if FinancialPayload.seal(revision, destination) ==
         {revision.canonical_payload, revision.payload_hash},
       do: :ok,
       else:
         {:payload_integrity, :revision_id,
          "no longer matches its sealed payload; it was altered outside Tauros"}
  end

  defp usable?(_destination, decision) when decision != :approved, do: :ok
  defp usable?(%{state: :active}, :approved), do: :ok

  defp usable?(%{state: state}, :approved),
    do:
      {:destination_inactive, :revision_id,
       "pays to a destination that is #{state}; request changes instead"}

  defp conflict(changeset, code, field, message) do
    Ash.Changeset.add_error(
      changeset,
      Conflict.exception(code: code, field: field, message: message)
    )
  end

  defp lock(resource, id), do: Ash.get(resource, id, lock: :for_update, authorize?: false)

  defp existing_decision(invoice_id, revision_id) do
    Approval
    |> Ash.Query.filter(invoice_id == ^invoice_id and revision_id == ^revision_id)
    |> Ash.read_one!(authorize?: false)
  end

  defp current_revision(invoice_id) do
    InvoiceRevision
    |> Ash.Query.filter(invoice_id == ^invoice_id)
    |> Ash.Query.sort(number: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
