defmodule Tauros.Agents do
  @moduledoc """
  The Agents context.
  """

  import Ecto.Query, warn: false
  alias Tauros.Repo
  alias Tauros.Accounts.Scope

  alias Tauros.Agents.Agent

  @doc """
  Returns the list of agents for a given user.

  ## Examples

      iex> list_agents_for_user(user_id)
      [%Agent{}, ...]

  """
  def list_agents_for_user(user_id) do
    from(a in Agent, where: a.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of agents for the current scope user.

  ## Examples

      iex> list_agents(%Scope{user: user})
      [%Agent{}, ...]

  """
  def list_agents(%Scope{user: user}) do
    list_agents_for_user(user.id)
  end

  @doc """
  Gets a single agent.

  Raises `Ecto.NoResultsError` if the Agent does not exist.

  ## Examples

      iex> get_agent!(123)
      %Agent{}

      iex> get_agent!(456)
      ** (Ecto.NoResultsError)

  """
  def get_agent!(id), do: Repo.get!(Agent, id)

  @doc """
  Creates an agent with a provided API key from an external service.

  The API key is hashed before storage. Never persists plaintext API key.
  Returns the hashed agent for audit purposes (API key NOT included in response).

  ## Examples

      iex> create_agent(current_scope, %{"name" => "My Agent", "api_key" => "key_from_service"})
      {:ok, %Agent{}}

      iex> create_agent(current_scope, %{"name" => "My Agent"})
      {:error, %Ecto.Changeset{}}

  """
  def create_agent(%Scope{user: user}, attrs) do
    api_key = Map.get(attrs, "api_key") || Map.get(attrs, :api_key)

    if api_key do
      api_key_hash = Bcrypt.hash_pwd_salt(api_key)

      %Agent{}
      |> Agent.changeset(attrs)
      |> Ecto.Changeset.put_change(:user_id, user.id)
      |> Ecto.Changeset.put_change(:api_key_hash, api_key_hash)
      |> Repo.insert()
    else
      changeset = Agent.changeset(%Agent{}, attrs)
      {:error, Ecto.Changeset.add_error(changeset, :api_key, "can't be blank")}
    end
  end

  @doc """
  Updates a agent.

  ## Examples

      iex> update_agent(agent, %{field: new_value})
      {:ok, %Agent{}}

      iex> update_agent(agent, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a agent.

  ## Examples

      iex> delete_agent(agent)
      {:ok, %Agent{}}

      iex> delete_agent(agent)
      {:error, %Ecto.Changeset{}}

  """
  def delete_agent(%Agent{} = agent) do
    Repo.delete(agent)
  end

  @doc """
  Gets an agent by verifying their API key.

  Hashes the provided plaintext API key and matches against stored hashes.

  ## Examples

      iex> get_agent_by_api_key("valid_key_from_service")
      {:ok, %Agent{}}

      iex> get_agent_by_api_key("invalid_key")
      {:error, :unauthorized}

  """
  def get_agent_by_api_key(api_key) when is_binary(api_key) do
    agents = from(a in Agent) |> Repo.all()

    case Enum.find(agents, &Bcrypt.verify_pass(api_key, &1.api_key_hash)) do
      %Agent{} = agent -> {:ok, agent}
      nil -> {:error, :unauthorized}
    end
  end

  def get_agent_by_api_key(_), do: {:error, :invalid}

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking agent changes.

  ## Examples

      iex> change_agent(agent)
      %Ecto.Changeset{data: %Agent{}}

  """
  def change_agent(%Agent{} = agent, attrs \\ %{}) do
    Agent.changeset(agent, attrs)
  end
end
