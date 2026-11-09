defmodule Boonorbust2.Repo.Migrations.AddTargetAllocationPercentToPortfolioTags do
  use Ecto.Migration

  def change do
    alter table(:portfolio_tags) do
      add :target_allocation_percent, :decimal, precision: 5, scale: 2
    end

    create constraint(:portfolio_tags, :target_allocation_percent_must_be_percent,
             check: "target_allocation_percent >= 0 AND target_allocation_percent <= 100"
           )
  end
end
