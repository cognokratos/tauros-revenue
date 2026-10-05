defmodule Tauros.Revenue.Invoice.Validations.Submittable do
  @moduledoc """
  The current revision can be put in front of a human only if nobody has
  decided on it yet (after "request changes" the agent must revise first) and
  its payment destination is still active.

  Declared with `before_action?: true` after the `Transition` change, so it
  reads the locked invoice inside the transaction. A retried submit (already
  pending) is a no-op and is not re-validated.
  """
  use Ash.Resource.Validation

  alias Tauros.Revenue.Changes.Transition

  @impl true
  def validate(changeset, _opts, _context) do
    if Transition.replay?(changeset) do
      :ok
    else
      changeset.data
      |> Ash.load!([current_revision: [:payment_destination, :approval]], authorize?: false)
      |> Map.fetch!(:current_revision)
      |> check()
    end
  end

  defp check(%{approval: %{decision: decision}}) do
    {:error,
     field: :current_revision,
     message: "was already decided (#{decision}); revise the invoice before submitting it again"}
  end

  defp check(%{payment_destination: %{state: :active}}), do: :ok

  defp check(%{payment_destination: %{state: state}}) do
    {:error,
     field: :payment_destination_id,
     message: "is #{state}; revise the invoice with an active destination before submitting"}
  end
end
