defmodule Boonorbust2.Repo.Migrations.CreatePortfolioTags do
  use Ecto.Migration

  def change do
    create table(:portfolio_tags) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:portfolio_tags, [:portfolio_id])
    create index(:portfolio_tags, [:tag_id])
    create unique_index(:portfolio_tags, [:portfolio_id, :tag_id])
  end
end
