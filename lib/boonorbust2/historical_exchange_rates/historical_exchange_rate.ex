defmodule Boonorbust2.HistoricalExchangeRates.HistoricalExchangeRate do
  @moduledoc """
  Schema and changeset functions for historical exchange rates.

  Stores the full quotes map fetched from Frankfurter for a given date and
  base currency. The combination of date and base_currency is unique.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          date: Date.t() | nil,
          base_currency: String.t() | nil,
          rates: map() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "historical_exchange_rates" do
    field :date, :date
    field :base_currency, :string
    field :rates, :map

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(historical_exchange_rate, attrs) do
    historical_exchange_rate
    |> cast(attrs, [:date, :base_currency, :rates])
    |> validate_required([:date, :base_currency, :rates])
    |> unique_constraint([:date, :base_currency],
      name: :historical_exchange_rates_date_base_currency_index
    )
  end
end
