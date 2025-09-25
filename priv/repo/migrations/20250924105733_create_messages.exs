defmodule Boonorbust2.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :string
      add :author, :string

      timestamps(type: :utc_datetime)
    end
  end
end
