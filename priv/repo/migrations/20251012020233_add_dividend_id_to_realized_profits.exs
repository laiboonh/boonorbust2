defmodule Boonorbust2.Repo.Migrations.AddDividendIdToRealizedProfits do
  use Ecto.Migration

  def up do
    # Drop the existing foreign key constraint
    execute "ALTER TABLE realized_profits DROP CONSTRAINT realized_profits_portfolio_transaction_id_fkey"

    # Make portfolio_transaction_id nullable
    execute "ALTER TABLE realized_profits ALTER COLUMN portfolio_transaction_id DROP NOT NULL"

    # Re-add the foreign key constraint
    execute "ALTER TABLE realized_profits ADD CONSTRAINT realized_profits_portfolio_transaction_id_fkey FOREIGN KEY (portfolio_transaction_id) REFERENCES portfolio_transactions(id) ON DELETE CASCADE"

    # Add dividend_id column
    alter table(:realized_profits) do
      add :dividend_id, references(:dividends, on_delete: :delete_all), null: true
    end

    # Add check constraint to ensure at least one of portfolio_transaction_id or dividend_id is set
    create constraint(:realized_profits, :must_have_transaction_or_dividend,
             check: "portfolio_transaction_id IS NOT NULL OR dividend_id IS NOT NULL"
           )

    # Add index on dividend_id for faster queries
    create index(:realized_profits, [:dividend_id])

    # Add unique constraint on (user_id, dividend_id) to ensure one realized profit per dividend per user
    create unique_index(:realized_profits, [:user_id, :dividend_id],
             where: "dividend_id IS NOT NULL",
             name: :realized_profits_user_dividend_index
           )
  end

  def down do
    # Drop the unique index on (user_id, dividend_id)
    drop index(:realized_profits, [:user_id, :dividend_id],
           where: "dividend_id IS NOT NULL",
           name: :realized_profits_user_dividend_index
         )

    # Drop the index on dividend_id
    drop index(:realized_profits, [:dividend_id])

    # Drop the check constraint
    drop constraint(:realized_profits, :must_have_transaction_or_dividend)

    # Drop dividend_id column
    alter table(:realized_profits) do
      remove :dividend_id
    end

    # Drop the foreign key constraint
    execute "ALTER TABLE realized_profits DROP CONSTRAINT realized_profits_portfolio_transaction_id_fkey"

    # Make portfolio_transaction_id NOT NULL again
    execute "ALTER TABLE realized_profits ALTER COLUMN portfolio_transaction_id SET NOT NULL"

    # Re-add the foreign key constraint with original settings
    execute "ALTER TABLE realized_profits ADD CONSTRAINT realized_profits_portfolio_transaction_id_fkey FOREIGN KEY (portfolio_transaction_id) REFERENCES portfolio_transactions(id) ON DELETE CASCADE"
  end
end
