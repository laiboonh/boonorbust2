defmodule Boonorbust2.Repo.Migrations.AddXorConstraintToRealizedProfits do
  use Ecto.Migration

  def up do
    create constraint(:realized_profits, :exactly_one_of_transaction_or_dividend,
             check: "num_nonnulls(portfolio_transaction_id, dividend_id) = 1"
           )
  end

  def down do
    drop constraint(:realized_profits, :exactly_one_of_transaction_or_dividend)
  end
end
