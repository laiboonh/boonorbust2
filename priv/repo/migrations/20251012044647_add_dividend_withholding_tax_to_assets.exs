defmodule Boonorbust2.Repo.Migrations.AddDividendWithholdingTaxToAssets do
  use Ecto.Migration

  def change do
    alter table(:assets) do
      add :dividend_withholding_tax, :decimal, precision: 5, scale: 4
    end
  end
end
