defmodule Tauros.Revenue.Invoice.Changes.RecordEvent do
  @moduledoc """
  Appends an `InvoiceEvent` in the same transaction as the invoice command.

  Replays (idempotent no-ops) record nothing, because nothing happened. The
  interface comes from the Ash context: the JSON:API pipeline sets
  `interface: :api`, the LiveViews pass `interface: :ui`, and anything else is
  `:console`.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Tauros.Revenue.{InvoiceEvent, InvoiceRevision}
  alias Tauros.Revenue.Changes.Transition

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, invoice ->
      if Transition.replay?(changeset),
        do: {:ok, invoice},
        else: record(changeset, invoice, context.actor)
    end)
  end

  defp record(changeset, invoice, actor) do
    revision = current_revision(invoice.id)

    InvoiceEvent
    |> Ash.Changeset.for_create(:record, %{
      invoice_id: invoice.id,
      action: changeset.action.name,
      # For updates, `data` is the row as locked by the action, not the caller's copy.
      from_state: if(changeset.action_type == :update, do: changeset.data.state),
      to_state: invoice.state,
      actor_id: actor.id,
      actor_kind: kind(actor),
      interface: changeset.context[:interface] || :console,
      revision_id: revision && revision.id,
      payload_hash: revision && revision.payload_hash,
      idempotency_key: if(changeset.action_type == :create, do: invoice.idempotency_key),
      note:
        Ash.Changeset.get_argument(changeset, :reasoning) ||
          Ash.Changeset.get_argument(changeset, :reason)
    })
    # Inside an action that has already been authorized; no actor may write events.
    |> Ash.create(authorize?: false)
    |> case do
      {:ok, _event} -> {:ok, invoice}
      {:error, error} -> {:error, error}
    end
  end

  defp kind(%Tauros.Accounts.User{}), do: :human
  defp kind(%Tauros.Accounts.Agent{}), do: :agent

  defp current_revision(invoice_id) do
    InvoiceRevision
    |> Ash.Query.filter(invoice_id == ^invoice_id)
    |> Ash.Query.sort(number: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
