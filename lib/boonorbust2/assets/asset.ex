defmodule Boonorbust2.Assets.Asset do
  @moduledoc """
  Schema and changeset functions for assets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          code: String.t() | nil,
          price: Decimal.t() | nil,
          currency: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "assets" do
    field :name, :string
    field :code, :string
    field :price, :decimal
    field :currency, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:name, :code, :price, :currency])
    |> validate_required([:name, :code, :currency])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
  end
end
