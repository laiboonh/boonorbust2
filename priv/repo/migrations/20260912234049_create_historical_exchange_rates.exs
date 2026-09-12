defmodule Boonorbust2.Repo.Migrations.CreateHistoricalExchangeRates do
  use Ecto.Migration

  def change do
    create table(:historical_exchange_rates) do
      add :date, :date, null: false
      add :base_currency, :string, null: false
      add :rates, :map, null: false

      timestamps()
    end

    create unique_index(:historical_exchange_rates, [:date, :base_currency])
  end
end
