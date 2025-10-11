defmodule Boonorbust2.Repo.Migrations.CreatePortfolioSnapshots do
  use Ecto.Migration

  def change do
    create table(:portfolio_snapshots) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :snapshot_date, :date, null: false
      add :total_value, :money_with_currency, null: false

      timestamps()
    end

    create unique_index(:portfolio_snapshots, [:user_id, :snapshot_date])
    create index(:portfolio_snapshots, [:user_id])
  end
end
