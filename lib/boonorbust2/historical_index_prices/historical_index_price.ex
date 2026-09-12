defmodule Boonorbust2.HistoricalIndexPrices.HistoricalIndexPrice do
  @moduledoc """
  Schema and changeset functions for historical index prices.

  Stores the closing price fetched from Yahoo Finance for a given date and
  ticker. The combination of date and ticker is unique.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          date: Date.t() | nil,
          ticker: String.t() | nil,
          close: float() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "historical_index_prices" do
    field :date, :date
    field :ticker, :string
    field :close, :float

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(historical_index_price, attrs) do
    historical_index_price
    |> cast(attrs, [:date, :ticker, :close])
    |> validate_required([:date, :ticker, :close])
    |> unique_constraint([:date, :ticker],
      name: :historical_index_prices_date_ticker_index
    )
  end
end
