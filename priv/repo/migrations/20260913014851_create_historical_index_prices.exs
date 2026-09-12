defmodule Boonorbust2.Repo.Migrations.CreateHistoricalIndexPrices do
  use Ecto.Migration

  def change do
    create table(:historical_index_prices) do
      add :date, :date, null: false
      add :ticker, :string, null: false
      add :close, :float, null: false

      timestamps()
    end

    create unique_index(:historical_index_prices, [:date, :ticker])
  end
end
