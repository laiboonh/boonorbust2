defmodule Boonorbust2.Repo.Migrations.RemoveColorFromTags do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      remove :color
    end
  end
end
