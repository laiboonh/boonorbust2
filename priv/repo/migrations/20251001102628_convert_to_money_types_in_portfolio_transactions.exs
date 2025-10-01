defmodule Boonorbust2.Repo.Migrations.ConvertToMoneyTypesInPortfolioTransactions do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE public.money_with_currency AS (currency char(3), amount numeric)")

    alter table(:portfolio_transactions) do
      remove :price
      remove :commission
      remove :currency

      add :price, :money_with_currency, null: false
      add :commission, :money_with_currency, null: false
    end
  end

  def down do
    alter table(:portfolio_transactions) do
      remove :price
      remove :commission

      add :price, :decimal, null: false
      add :commission, :decimal, null: false
      add :currency, :string, size: 3, null: false, default: "SGD"
    end

    execute("DROP TYPE public.money_with_currency")
  end
end
