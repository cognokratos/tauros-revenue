defmodule Tauros.Customers.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "customers" do
    field :name, :string
    field :email, :string
    belongs_to :agent, Tauros.Agents.Agent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:name, :email, :agent_id])
    |> validate_required([:name, :email, :agent_id])
    |> validate_change(:agent_id, fn :agent_id, val ->
      if is_binary(val) and val != "" do
        []
      else
        [agent_id: "is required"]
      end
    end)
  end
end
