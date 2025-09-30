defmodule Boonorbust2.Repo.Migrations.CreatePortfolioTransactions do
  use Ecto.Migration

  def change do
    create table(:portfolio_transactions) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :shares, :decimal, null: false
      add :price, :decimal, null: false
      add :commission, :decimal, null: false
      add :amount, :decimal, null: false
      add :transaction_date, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolio_transactions, [:asset_id])
    create index(:portfolio_transactions, [:transaction_date])
    create index(:portfolio_transactions, [:action])
  end
end
