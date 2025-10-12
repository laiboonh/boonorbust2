defmodule Boonorbust2.Assets.Asset do
  @moduledoc """
  Schema and changeset functions for assets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Currency
  alias Boonorbust2.Dividends.Dividend
  alias Boonorbust2.Tags.AssetTag

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          price_url: String.t() | nil,
          price: Decimal.t() | nil,
          currency: String.t() | nil,
          distributes_dividends: boolean() | nil,
          dividend_url: String.t() | nil,
          dividend_withholding_tax: Decimal.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "assets" do
    field :name, :string
    field :price_url, :string
    field :price, :decimal
    field :currency, :string
    field :distributes_dividends, :boolean, default: false
    field :dividend_url, :string
    field :dividend_withholding_tax, :decimal

    has_many :asset_tags, AssetTag
    has_many :dividends, Dividend

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [
      :name,
      :price_url,
      :price,
      :currency,
      :distributes_dividends,
      :dividend_url,
      :dividend_withholding_tax
    ])
    |> validate_required([:name, :currency])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:dividend_withholding_tax,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_inclusion(:currency, Currency.supported_currencies())
    |> validate_url(:price_url)
    |> validate_url(:dividend_url)
    |> validate_dividend_url_required()
    |> validate_dividend_withholding_tax_required()
  end

  @spec validate_dividend_url_required(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_dividend_url_required(changeset) do
    distributes_dividends = get_field(changeset, :distributes_dividends)
    dividend_url = get_field(changeset, :dividend_url)

    cond do
      # If distributes_dividends is true, dividend_url must be present
      distributes_dividends && is_nil(dividend_url) ->
        add_error(changeset, :dividend_url, "is required when asset distributes dividends")

      # If dividend_url is present, distributes_dividends must be true
      not is_nil(dividend_url) && dividend_url != "" && !distributes_dividends ->
        add_error(
          changeset,
          :distributes_dividends,
          "must be checked when dividend URL is provided"
        )

      true ->
        changeset
    end
  end

  @spec validate_dividend_withholding_tax_required(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_dividend_withholding_tax_required(changeset) do
    distributes_dividends = get_field(changeset, :distributes_dividends)
    dividend_withholding_tax = get_field(changeset, :dividend_withholding_tax)

    cond do
      # If distributes_dividends is true, dividend_withholding_tax must be present
      distributes_dividends && is_nil(dividend_withholding_tax) ->
        add_error(
          changeset,
          :dividend_withholding_tax,
          "is required when asset distributes dividends"
        )

      # If dividend_withholding_tax is present, distributes_dividends must be true
      not is_nil(dividend_withholding_tax) && !distributes_dividends ->
        add_error(
          changeset,
          :distributes_dividends,
          "must be checked when dividend withholding tax is provided"
        )

      true ->
        changeset
    end
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
