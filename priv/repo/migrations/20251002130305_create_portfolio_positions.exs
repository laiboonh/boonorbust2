defmodule Boonorbust2.Repo.Migrations.CreatePortfolioPositions do
  use Ecto.Migration

  def up do
    # Drop portfolio_transactions table (will be recreated with new money type)
    drop table(:portfolio_transactions)

    # Drop and recreate money_with_currency type with numeric(19,4) precision
    execute("DROP TYPE public.money_with_currency")
    execute("CREATE TYPE public.money_with_currency AS (currency char(3), amount numeric(19,4))")

    # Recreate portfolio_transactions table with final structure
    create table(:portfolio_transactions) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :quantity, :decimal, null: false
      add :price, :money_with_currency, null: false
      add :commission, :money_with_currency, null: false
      add :amount, :money_with_currency, null: false
      add :transaction_date, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolio_transactions, [:asset_id])
    create index(:portfolio_transactions, [:transaction_date])
    create index(:portfolio_transactions, [:action])

    # Create portfolio_positions table
    create table(:portfolio_positions) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :portfolio_transaction_id, references(:portfolio_transactions, on_delete: :delete_all)
      add :average_price, :money_with_currency, null: false
      add :quantity_on_hand, :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolio_positions, [:asset_id])
    create unique_index(:portfolio_positions, [:portfolio_transaction_id])
  end

  def down do
    # Drop tables
    drop table(:portfolio_positions)
    drop table(:portfolio_transactions)

    # Drop and recreate money_with_currency type with unlimited precision
    execute("DROP TYPE public.money_with_currency")
    execute("CREATE TYPE public.money_with_currency AS (currency char(3), amount numeric)")

    # Recreate portfolio_transactions with old type
    create table(:portfolio_transactions) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :quantity, :decimal, null: false
      add :price, :money_with_currency, null: false
      add :commission, :money_with_currency, null: false
      add :amount, :money_with_currency, null: false
      add :transaction_date, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolio_transactions, [:asset_id])
    create index(:portfolio_transactions, [:transaction_date])
    create index(:portfolio_transactions, [:action])
  end
end
