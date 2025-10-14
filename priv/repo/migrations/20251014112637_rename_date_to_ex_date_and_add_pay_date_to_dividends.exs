defmodule Boonorbust2.Repo.Migrations.RenameDateToExDateAndAddPayDateToDividends do
  use Ecto.Migration

  def change do
    # Rename date column to ex_date
    rename table(:dividends), :date, to: :ex_date

    # Add nullable pay_date column
    alter table(:dividends) do
      add :pay_date, :date
    end
  end
end
