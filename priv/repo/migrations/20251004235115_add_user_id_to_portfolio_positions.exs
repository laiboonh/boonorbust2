defmodule Boonorbust2.Repo.Migrations.AddUserIdToPortfolioPositions do
  use Ecto.Migration

  def change do
    alter table(:portfolio_positions) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end

    create index(:portfolio_positions, [:user_id])
  end
end
