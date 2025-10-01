defmodule Boonorbust2.Repo.Migrations.ConvertAmountToMoneyInPortfolioTransactions do
  use Ecto.Migration

  def up do
    alter table(:portfolio_transactions) do
      remove :amount
      add :amount, :money_with_currency, null: false
    end
  end

  def down do
    alter table(:portfolio_transactions) do
      remove :amount
      add :amount, :decimal, null: false
    end
  end
end
