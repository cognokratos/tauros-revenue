defmodule Tauros.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agents" do
    field :name, :string
    field :api_key_hash, :string
    field :api_key, :string, virtual: true
    belongs_to :user, Tauros.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name, :api_key])
    |> validate_required([:name, :api_key])
  end
end
