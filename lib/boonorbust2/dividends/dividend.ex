defmodule Boonorbust2.Dividends.Dividend do
  @moduledoc """
  Schema and changeset functions for dividends.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Currency

  @type t :: %__MODULE__{
          id: integer() | nil,
          asset_id: integer() | nil,
          ex_date: Date.t() | nil,
          pay_date: Date.t() | nil,
          value: Decimal.t() | nil,
          currency: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "dividends" do
    field :ex_date, :date
    field :pay_date, :date
    field :value, :decimal
    field :currency, :string

    belongs_to :asset, Asset

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(dividend, attrs) do
    dividend
    |> cast(attrs, [:asset_id, :ex_date, :pay_date, :value, :currency])
    |> validate_required([:asset_id, :ex_date, :value, :currency])
    |> validate_number(:value, greater_than_or_equal_to: 0)
    |> validate_inclusion(:currency, Currency.supported_currencies())
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :ex_date])
  end
end
