defmodule Tauros.Revenue.PaymentDestination.Validations.SupersedesOwnDestination do
  @moduledoc """
  A destination can only replace an active destination of the same agent.

  An unknown id and another agent's id get the same error, so the response
  does not reveal whether someone else's destination exists.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, %{actor: %Tauros.Accounts.Agent{id: agent_id}}) do
    id = Ash.Changeset.get_attribute(changeset, :supersedes_id)

    case Ash.get(changeset.resource, id, authorize?: false, error?: false) do
      {:ok, %{agent_id: ^agent_id, state: :active}} -> :ok
      _ -> {:error, field: :supersedes_id, message: "is not one of your active destinations"}
    end
  end

  # Non-agent actors are refused by the create policy.
  def validate(_changeset, _opts, _context), do: :ok
end
