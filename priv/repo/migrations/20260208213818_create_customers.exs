defmodule Tauros.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :agent_id, references(:agents, on_delete: :restrict, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:customers, [:agent_id])
  end
end
