defmodule Tauros.Accounts.Agent.Changes.IssueApiKey do
  @moduledoc """
  Issues a fresh API key for the agent, revoking any previous keys.

  The plaintext key exists only in the action result's metadata
  (`agent.__metadata__.plaintext_api_key`); only its hash is persisted.
  """
  use Ash.Resource.Change
  require Ash.Query

  @validity_days 365

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, agent ->
      Tauros.Accounts.ApiKey
      |> Ash.Query.filter(agent_id == ^agent.id)
      |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)

      api_key =
        Tauros.Accounts.ApiKey
        |> Ash.Changeset.for_create(:create, %{
          agent_id: agent.id,
          expires_at: DateTime.add(DateTime.utc_now(), @validity_days, :day)
        })
        |> Ash.create!(authorize?: false)

      {:ok,
       Ash.Resource.put_metadata(
         agent,
         :plaintext_api_key,
         api_key.__metadata__.plaintext_api_key
       )}
    end)
  end
end
