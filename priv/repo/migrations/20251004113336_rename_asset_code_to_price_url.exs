defmodule Boonorbust2.Repo.Migrations.RenameAssetCodeToPriceUrl do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:assets, [:code])
    rename table(:assets), :code, to: :price_url

    alter table(:assets) do
      modify :price_url, :string, null: true
    end
  end
end
