defmodule Boonorbust2.Repo.Migrations.RenameSharesToQuantityInPortfolioTransactions do
  use Ecto.Migration

  def change do
    rename table(:portfolio_transactions), :shares, to: :quantity
  end
end
