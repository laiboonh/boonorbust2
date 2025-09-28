defmodule Boonorbust2.Repo.Migrations.AddCurrencyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :currency, :string, default: "SGD", null: false
    end
  end
end
