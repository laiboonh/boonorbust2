defmodule Boonorbust2.Repo.Migrations.AddDistributesDividendsToAssets do
  use Ecto.Migration

  def change do
    alter table(:assets) do
      add :distributes_dividends, :boolean, default: false, null: false
    end
  end
end
