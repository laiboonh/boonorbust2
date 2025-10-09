defmodule Boonorbust2.Repo.Migrations.CreatePortfolios do
  use Ecto.Migration

  def change do
    create table(:portfolios) do
      add :name, :string, null: false
      add :description, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolios, [:user_id])
    create unique_index(:portfolios, [:user_id, :name])
  end
end
