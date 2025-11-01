defmodule Boonorbust2.Repo.Migrations.AddNotesToPortfolioTransactions do
  use Ecto.Migration

  def change do
    alter table(:portfolio_transactions) do
      add :notes, :text
    end
  end
end
