defmodule TaurosWeb.Api.Admin.CustomerJSON do
  alias Tauros.Customers.Customer

  @doc """
  Renders a list of customers.
  """
  def index(%{customers: customers}) do
    %{data: for(customer <- customers, do: data(customer))}
  end

  @doc """
  Renders a single customer.
  """
  def show(%{customer: customer}) do
    %{data: data(customer)}
  end

  defp data(%Customer{} = customer) do
    %{
      id: customer.id,
      name: customer.name,
      email: customer.email,
      agent_id: customer.agent_id,
      inserted_at: customer.inserted_at,
      updated_at: customer.updated_at
    }
  end
end
