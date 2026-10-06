defmodule Tauros.Revenue.Changes.Transition do
  @moduledoc """
  Moves a record through its AshStateMachine lifecycle, checked against the
  row as it is now, under a lock.

  AshStateMachine's built-in `transition_state/1` checks the struct the caller
  loaded. Two approvers who loaded the same pending invoice would both pass
  that check. This change locks the row (`SELECT … FOR UPDATE`) inside the
  action's transaction, reloads it and then asks the state machine. Concurrent
  transitions on one record therefore run one after the other, and the second
  sees the first one's result. The `transitions` block of the resource stays
  the only definition of which moves are legal.

  ## Options

    * `:to` (required): the target state.
    * `:idempotent?`: if the row is already in `:to`, succeed without writing,
      so a retried command is a no-op. Defaults to `false`.

  Later `before_action` hooks and validations declared with
  `before_action?: true` run after this one, on the locked record.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    if is_atom(opts[:to]) and not is_nil(opts[:to]),
      do: {:ok, opts},
      else: {:error, "`to` must be the target state"}
  end

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case lock(changeset) do
        {:ok, current} -> transition(%{changeset | data: current}, opts)
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end

  @doc false
  def replay?(changeset), do: changeset.context[:replay?] == true

  defp transition(changeset, opts) do
    state = AshStateMachine.Info.state_machine_state_attribute!(changeset.resource)

    if opts[:idempotent?] && Map.fetch!(changeset.data, state) == opts[:to] do
      changeset
      |> Ash.Changeset.set_context(%{replay?: true})
      |> Ash.Changeset.set_result({:ok, changeset.data})
    else
      AshStateMachine.transition_state(changeset, opts[:to])
    end
  end

  defp lock(changeset) do
    primary_key = changeset.data |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))

    Ash.get(changeset.resource, primary_key,
      domain: changeset.domain,
      lock: :for_update,
      authorize?: false
    )
  end
end
