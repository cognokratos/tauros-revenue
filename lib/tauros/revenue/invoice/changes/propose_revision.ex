defmodule Tauros.Revenue.Invoice.Changes.ProposeRevision do
  @moduledoc """
  Turns an agent's proposal into an immutable `InvoiceRevision`, safely under
  retries.

  **`create_draft`**: the agent's row is locked (`FOR UPDATE`), so concurrent
  creates by one agent run one after another. Then the idempotency key is
  looked up:

    * not used yet: the invoice is created with revision 1
    * used, and the payload hashes the same as that invoice's first revision:
      the original invoice is returned with `idempotent_replay: true` and
      nothing is written
    * used with a different payload: refused with `idempotency_conflict`

  The payload compared is the `FinancialPayload`. The reasoning is not part of
  it, so a retry whose explanation is worded differently is still a replay.

  **`revise`**: omitted fields keep the current revision's values. If the
  result hashes the same as the current revision, nothing is written (and a
  pending invoice stays pending). Otherwise a new revision is appended.

  The revision itself is created through `manage_relationship`, which is the
  only way `InvoiceRevision`'s create policy lets one be written.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Tauros.Revenue.{FinancialPayload, Invoice, InvoiceRevision, PaymentDestination}
  alias Tauros.Revenue.Changes.Transition
  alias Tauros.Revenue.Errors.Conflict

  @fields [:customer_id, :payment_destination_id, :currency, :due_date, :lines]

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      cond do
        not changeset.valid? or Transition.replay?(changeset) -> changeset
        changeset.action_type == :create -> propose_first(changeset)
        true -> propose_next(changeset)
      end
    end)
    |> Ash.Changeset.after_action(fn changeset, invoice ->
      {:ok, Ash.Resource.put_metadata(invoice, :idempotent_replay, replay?(changeset))}
    end)
  end

  defp propose_first(changeset) do
    agent_id = Ash.Changeset.get_attribute(changeset, :agent_id)
    key = Ash.Changeset.get_attribute(changeset, :idempotency_key)
    input = input(changeset, %{})

    lock_agent!(agent_id)

    case existing(agent_id, key) do
      nil ->
        create_revision(changeset, input)

      invoice ->
        if payload_hash(input) == first_revision(invoice).payload_hash do
          replay(changeset, invoice)
        else
          Ash.Changeset.add_error(
            changeset,
            Conflict.exception(
              code: :idempotency_conflict,
              field: :idempotency_key,
              message: "was already used by this agent for a different financial payload"
            )
          )
        end
    end
  end

  defp propose_next(changeset) do
    current = current_revision(changeset.data)
    input = input(changeset, current)

    if payload_hash(input) == current.payload_hash,
      do: replay(changeset, changeset.data),
      else: create_revision(changeset, input)
  end

  defp create_revision(changeset, input) do
    Ash.Changeset.manage_relationship(changeset, :revisions, [input], type: :create)
  end

  defp replay(changeset, invoice) do
    changeset
    |> Ash.Changeset.set_context(%{replay?: true})
    |> Ash.Changeset.set_result({:ok, invoice})
  end

  defp replay?(changeset), do: Transition.replay?(changeset)

  # Arguments the caller gave, falling back to the current revision's values.
  defp input(changeset, defaults) do
    @fields
    |> Map.new(fn field ->
      {field, Ash.Changeset.get_argument(changeset, field) || Map.get(defaults, field)}
    end)
    |> Map.update!(:lines, fn lines -> lines && Enum.map(lines, &line_input/1) end)
    |> Map.put(:reasoning, Ash.Changeset.get_argument(changeset, :reasoning))
  end

  defp line_input(line), do: Map.take(line, [:description, :quantity, :unit_amount])

  # The hash the revision would get. `nil` (never equal to a stored hash) if
  # the input is incomplete or names an unknown destination.
  defp payload_hash(%{payment_destination_id: id, lines: lines} = input)
       when is_binary(id) and is_list(lines) do
    case Ash.get(PaymentDestination, id, authorize?: false, error?: false) do
      {:ok, %PaymentDestination{} = destination} ->
        input |> FinancialPayload.seal(destination) |> elem(1)

      _ ->
        nil
    end
  end

  defp payload_hash(_input), do: nil

  defp lock_agent!(agent_id),
    do: Ash.get!(Tauros.Accounts.Agent, agent_id, lock: :for_update, authorize?: false)

  defp existing(agent_id, key) do
    Invoice
    |> Ash.Query.filter(agent_id == ^agent_id and idempotency_key == ^key)
    |> Ash.read_one!(authorize?: false)
  end

  defp first_revision(invoice) do
    InvoiceRevision
    |> Ash.Query.filter(invoice_id == ^invoice.id and number == 1)
    |> Ash.read_one!(authorize?: false)
  end

  defp current_revision(invoice) do
    InvoiceRevision
    |> Ash.Query.filter(invoice_id == ^invoice.id)
    |> Ash.Query.sort(number: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
