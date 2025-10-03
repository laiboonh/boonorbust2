defmodule Boonorbust2.Repo.Migrations.AddAmountOnHandToPortfolioPositions do
  use Ecto.Migration

  def change do
    alter table(:portfolio_positions) do
      add :amount_on_hand, :money_with_currency, null: false
    end
  end
end
