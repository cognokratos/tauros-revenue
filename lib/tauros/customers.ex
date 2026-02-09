defmodule Tauros.Customers do
  @moduledoc """
  The Customers context.
  """

  import Ecto.Query, warn: false
  alias Tauros.Repo
  alias Tauros.Customers.Customer
  alias Tauros.Accounts.Scope
  alias Tauros.Agents

  @doc """
  Returns the list of customers scoped to the user's agents.

  ## Examples

      iex> list_customers(scope)
      [%Customer{}, ...]

  """
  def list_customers(%Scope{} = scope) do
    user_agent_ids =
      Agents.list_agents(scope)
      |> Enum.map(& &1.id)

    Repo.all(
      from c in Customer,
        where: c.agent_id in ^user_agent_ids,
        preload: [:agent],
        order_by: [desc: c.inserted_at]
    )
  end

  @doc """
  Gets a single customer.

  Ensures the customer belongs to an agent owned by the current user.

  Raises `Ecto.NoResultsError` if the Customer does not exist or doesn't belong to user.

  ## Examples

      iex> get_customer!(scope, id)
      %Customer{}

  """
  def get_customer!(%Scope{} = scope, id) do
    user_agent_ids =
      Agents.list_agents(scope)
      |> Enum.map(& &1.id)

    Repo.one!(
      from c in Customer,
        where: c.id == ^id and c.agent_id in ^user_agent_ids,
        preload: [:agent]
    )
  end

  @doc """
  Creates a customer.

  The `agent_id` is required and must belong to the current user.

  ## Examples

      iex> create_customer(scope, %{name: "Acme Inc", email: "contact@acme.com", agent_id: "..."})
      {:ok, %Customer{}}

      iex> create_customer(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_customer(%Scope{} = scope, attrs) do
    # Verify agent_id belongs to the current user
    agent_id = attrs["agent_id"] || attrs[:agent_id]

    # Create changeset first to validate all fields
    changeset = %Customer{} |> Customer.changeset(attrs)

    # Check if changeset is valid
    if (changeset.valid? and agent_id) && agent_id != "" &&
         agent_belongs_to_user?(scope, agent_id) do
      Repo.insert(changeset)
    else
      # Return changeset errors or custom error
      if not changeset.valid? do
        {:error, changeset}
      else
        {:error, "Agent not found or does not belong to your account"}
      end
    end
  end

  @doc """
  Updates a customer.

  The `agent_id` cannot be reassigned and will be rejected if present in the update params.

  ## Examples

      iex> update_customer(scope, customer, %{field: new_value})
      {:ok, %Customer{}}

      iex> update_customer(scope, customer, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_customer(%Scope{} = scope, %Customer{} = customer, attrs) do
    # Ensure customer belongs to user's agent
    _customer = get_customer!(scope, customer.id)

    # Check if agent_id is in params and reject if present
    has_agent_id_param = Map.has_key?(attrs, "agent_id") or Map.has_key?(attrs, :agent_id)

    changeset = Customer.update_changeset(customer, attrs)

    if has_agent_id_param do
      # Add error for agent_id reassignment attempt
      {:error, Ecto.Changeset.add_error(changeset, :agent_id, "cannot be reassigned")}
    else
      Repo.update(changeset)
    end
  end

  @doc """
  Deletes a customer.

  ## Examples

      iex> delete_customer(scope, customer)
      {:ok, %Customer{}}

      iex> delete_customer(scope, customer)
      {:error, %Ecto.Changeset{}}

  """
  def delete_customer(%Scope{} = scope, %Customer{} = customer) do
    # Ensure customer belongs to user's agent
    _customer = get_customer!(scope, customer.id)
    Repo.delete(customer)
  end

  @doc """
  Returns a changeset for tracking customer changes.

  ## Examples

      iex> change_customer(customer)
      %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer(%Customer{} = customer, attrs \\ %{}) do
    Customer.changeset(customer, attrs)
  end

  # Helper to check if an agent belongs to the current user
  defp agent_belongs_to_user?(%Scope{} = scope, agent_id) do
    Repo.exists?(
      from a in Tauros.Agents.Agent,
        where: a.id == ^agent_id and a.user_id == ^scope.user.id
    )
  end
end
