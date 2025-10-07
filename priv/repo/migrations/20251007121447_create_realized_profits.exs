defmodule Boonorbust2.Repo.Migrations.CreateRealizedProfits do
  use Ecto.Migration

  def change do
    create table(:realized_profits) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false

      add :portfolio_transaction_id, references(:portfolio_transactions, on_delete: :delete_all),
        null: false

      add :amount, :money_with_currency, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:realized_profits, [:user_id])
    create index(:realized_profits, [:asset_id])
    create unique_index(:realized_profits, [:portfolio_transaction_id])
  end
end
