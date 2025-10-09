defmodule Boonorbust2.Repo.Migrations.RemoveUserIdFromAssetTags do
  use Ecto.Migration

  def change do
    # Drop the old unique index that includes user_id
    drop unique_index(:asset_tags, [:asset_id, :tag_id, :user_id])
    drop index(:asset_tags, [:user_id])

    # Remove user_id column
    alter table(:asset_tags) do
      remove :user_id
    end

    # Create new unique index without user_id
    create unique_index(:asset_tags, [:asset_id, :tag_id])
  end
end
