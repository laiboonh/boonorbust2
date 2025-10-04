defmodule Boonorbust2.Assets.Asset do
  @moduledoc """
  Schema and changeset functions for assets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Currency

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          price_url: String.t() | nil,
          price: Decimal.t() | nil,
          currency: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "assets" do
    field :name, :string
    field :price_url, :string
    field :price, :decimal
    field :currency, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:name, :price_url, :price, :currency])
    |> validate_required([:name, :currency])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_inclusion(:currency, Currency.supported_currencies())
    |> validate_url(:price_url)
  end

  @spec validate_url(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      uri = URI.parse(value)

      if uri.scheme in ["http", "https"] do
        []
      else
        [{field, "must be a valid URL starting with http:// or https://"}]
      end
    end)
  end
end
