defmodule Boonorbust2.Repo.Migrations.AddSyncTimestampsToAssets do
  use Ecto.Migration

  def change do
    alter table(:assets) do
      add :prices_synced_at, :utc_datetime, null: true
      add :dividends_synced_at, :utc_datetime, null: true
    end
  end
end
