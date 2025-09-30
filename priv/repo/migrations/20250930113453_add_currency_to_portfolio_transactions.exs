defmodule Boonorbust2.Repo.Migrations.AddCurrencyToPortfolioTransactions do
  use Ecto.Migration

  def change do
    alter table(:portfolio_transactions) do
      add :currency, :string, size: 3, null: false, default: "SGD"
    end
  end
end
