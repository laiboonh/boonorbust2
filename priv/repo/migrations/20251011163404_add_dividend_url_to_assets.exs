defmodule Boonorbust2.Repo.Migrations.AddDividendUrlToAssets do
  use Ecto.Migration

  def change do
    alter table(:assets) do
      add :dividend_url, :string
    end
  end
end
