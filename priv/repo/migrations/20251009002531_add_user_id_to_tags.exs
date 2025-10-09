defmodule Boonorbust2.Repo.Migrations.AddUserIdToTags do
  use Ecto.Migration

  def change do
    # Add user_id to tags table
    alter table(:tags) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    # Drop the old unique index on name
    drop unique_index(:tags, [:name])

    # Create new unique index on user_id and name
    create unique_index(:tags, [:user_id, :name])
    create index(:tags, [:user_id])
  end
end
