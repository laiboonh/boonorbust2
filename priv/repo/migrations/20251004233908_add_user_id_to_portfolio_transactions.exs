defmodule Boonorbust2.Repo.Migrations.AddUserIdToPortfolioTransactions do
  use Ecto.Migration

  def change do
    alter table(:portfolio_transactions) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end

    create index(:portfolio_transactions, [:user_id])
  end
end
