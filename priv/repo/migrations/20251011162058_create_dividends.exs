defmodule Boonorbust2.Repo.Migrations.CreateDividends do
  use Ecto.Migration

  def change do
    create table(:dividends) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :value, :decimal, precision: 15, scale: 4, null: false
      add :currency, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:dividends, [:asset_id])
    create unique_index(:dividends, [:asset_id, :date])
  end
end
