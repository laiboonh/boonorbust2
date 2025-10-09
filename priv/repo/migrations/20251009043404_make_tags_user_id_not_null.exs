defmodule Boonorbust2.Repo.Migrations.MakeTagsUserIdNotNull do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      modify :user_id, :binary_id, null: false
    end
  end
end
