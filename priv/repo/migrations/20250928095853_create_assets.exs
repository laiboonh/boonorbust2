defmodule Boonorbust2.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets) do
      add :name, :string, null: false
      add :code, :string, null: false
      add :price, :decimal, precision: 15, scale: 4
      add :currency, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:assets, [:code])
  end
end
