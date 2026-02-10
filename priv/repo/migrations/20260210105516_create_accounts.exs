defmodule Tauros.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :wallet_name, :string, null: false
      add :public_address, :string, null: false
      add :currency, :string, null: false
      add :agent_id, :binary_id, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:accounts, [:agent_id])

    create constraint(:accounts, :agent_fk,
             check: "agent_id IS NOT NULL",
             comment: "Agent ID must be present for scoping"
           )
  end
end
