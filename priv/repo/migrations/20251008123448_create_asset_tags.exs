defmodule Boonorbust2.Repo.Migrations.CreateAssetTags do
  use Ecto.Migration

  def change do
    create table(:asset_tags) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:asset_tags, [:asset_id])
    create index(:asset_tags, [:tag_id])
    create index(:asset_tags, [:user_id])
    create unique_index(:asset_tags, [:asset_id, :tag_id, :user_id])
  end
end
