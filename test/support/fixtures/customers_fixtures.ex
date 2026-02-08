defmodule Tauros.CustomersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tauros.Customers` context.
  """

  @doc """
  Generate a customer.
  """
  def customer_fixture(attrs \\ %{}) do
    agent_id = attrs["agent_id"] || attrs[:agent_id] || Tauros.AgentsFixtures.agent_fixture().id

    attrs =
      Enum.into(attrs, %{
        "name" => "Test Customer",
        "email" => "customer@example.com",
        "agent_id" => agent_id
      })

    {:ok, customer} = Tauros.Repo.insert(
      Tauros.Customers.Customer.changeset(%Tauros.Customers.Customer{}, attrs)
    )

    customer
  end
end
