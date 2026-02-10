defmodule Tauros.Wallets do
  @moduledoc """
  The Wallets context - manages wallet accounts for agents.

  All account operations are scoped to the owning agent.
  """

  import Ecto.Query, warn: false
  alias Tauros.Repo
  alias Tauros.Wallets.Account
  alias Tauros.Agents.Agent

  @doc """
  Creates an account for a given agent.

  Account is automatically scoped to the provided agent.
  Private keys are never accepted or stored - only public addresses.

  ## Examples

      iex> create_account(agent, %{"wallet_name" => "My Wallet", "public_address" => "0x...", "currency" => "USD"})
      {:ok, %Account{}}

      iex> create_account(agent, %{"wallet_name" => "Bad"})
      {:error, %Ecto.Changeset{}}
  """
  def create_account(%Agent{} = agent, attrs) do
    %Account{}
    |> Account.changeset_with_agent(attrs, agent.id)
    |> Repo.insert()
  end

  @doc """
  Gets a single account for a given agent.

  Raises `Ecto.NoResultsError` if the Account does not exist or belongs to a different agent.

  ## Examples

      iex> get_account!(agent, account_id)
      %Account{}

      iex> get_account!(agent, 999)
      ** (Ecto.NoResultsError)
  """
  def get_account!(%Agent{} = agent, account_id) do
    from(a in Account, where: a.id == ^account_id and a.agent_id == ^agent.id)
    |> Repo.one!()
  end

  @doc """
  Lists all accounts for a given agent.

  ## Examples

      iex> list_accounts_for_agent(agent)
      [%Account{}, ...]
  """
  def list_accounts_for_agent(%Agent{} = agent) do
    from(a in Account, where: a.agent_id == ^agent.id)
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking account changes.

  ## Examples

      iex> change_account(account)
      %Ecto.Changeset{data: %Account{}}
  """
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end
end
