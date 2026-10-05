defmodule Tauros.Revenue.PaymentDestination.Changes.SupersedePrevious do
  @moduledoc """
  When a new destination names the one it replaces (`supersedes_id`), moves the
  old one to `superseded` in the same transaction. If the old destination is
  no longer active by then, the state machine refuses and the new one is not
  created either.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, destination ->
      case destination.supersedes_id do
        nil -> {:ok, destination}
        id -> supersede(changeset.resource, id, destination)
      end
    end)
  end

  # Runs inside the create action, which has already authorized the agent;
  # `supersede` itself grants no actor access.
  defp supersede(resource, id, destination) do
    with {:ok, previous} <- Ash.get(resource, id, authorize?: false),
         {:ok, _} <-
           previous |> Ash.Changeset.for_update(:supersede) |> Ash.update(authorize?: false) do
      {:ok, destination}
    end
  end
end
