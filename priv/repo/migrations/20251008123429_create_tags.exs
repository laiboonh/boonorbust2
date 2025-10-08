defmodule Boonorbust2.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :color, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])
  end
end
