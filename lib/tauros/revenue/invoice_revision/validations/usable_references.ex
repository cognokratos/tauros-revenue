defmodule Tauros.Revenue.InvoiceRevision.Validations.UsableReferences do
  @moduledoc """
  A revision may only combine records that belong to the invoice's own agent,
  and only a destination that can still receive the invoice's currency.

  The ids come from the caller, so nothing about them is trusted. Each record
  is loaded and compared with the invoice's `agent_id`. An unknown id and an id
  belonging to another agent get the same error, so the response never reveals
  whether someone else's record exists.

  Runs in a `before_action` hook, inside the transaction, after the invoice
  row has been locked (see `Tauros.Revenue.Changes.Transition`).
  """
  use Ash.Resource.Validation

  alias Tauros.Revenue.{Customer, Invoice, PaymentDestination}

  @impl true
  def validate(changeset, _opts, _context) do
    with {:ok, invoice} <- load(Invoice, Ash.Changeset.get_attribute(changeset, :invoice_id)),
         :ok <- customer_belongs(changeset, invoice.agent_id) do
      destination_usable(changeset, invoice.agent_id)
    else
      :not_found -> {:error, field: :invoice_id, message: "does not exist"}
      error -> error
    end
  end

  defp customer_belongs(changeset, agent_id) do
    case load(Customer, Ash.Changeset.get_attribute(changeset, :customer_id)) do
      {:ok, %{agent_id: ^agent_id}} -> :ok
      _ -> {:error, field: :customer_id, message: "is not one of this agent's customers"}
    end
  end

  defp destination_usable(changeset, agent_id) do
    currency = Ash.Changeset.get_attribute(changeset, :currency)

    case load(PaymentDestination, Ash.Changeset.get_attribute(changeset, :payment_destination_id)) do
      {:ok, %{agent_id: ^agent_id, state: :active, currency: ^currency}} ->
        :ok

      {:ok, %{agent_id: ^agent_id, state: :active} = destination} ->
        {:error,
         field: :currency,
         message:
           "must match the destination, which receives #{destination.currency} on #{destination.network}"}

      {:ok, %{agent_id: ^agent_id, state: state}} ->
        {:error,
         field: :payment_destination_id, message: "is #{state}; choose an active destination"}

      _ ->
        {:error,
         field: :payment_destination_id,
         message: "is not one of this agent's payment destinations"}
    end
  end

  defp load(_resource, nil), do: :not_found

  defp load(resource, id) do
    case Ash.get(resource, id, authorize?: false, error?: false) do
      {:ok, nil} -> :not_found
      {:ok, record} -> {:ok, record}
      {:error, _} -> :not_found
    end
  end
end
