defmodule Boonorbust2.PortfolioTransactions.PortfolioTransaction do
  @moduledoc """
  Schema and changeset functions for portfolio transactions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Currency

  @type t :: %__MODULE__{
          id: integer() | nil,
          asset_id: integer() | nil,
          asset: Asset.t() | nil,
          action: String.t() | nil,
          shares: Decimal.t() | nil,
          price: Decimal.t() | nil,
          commission: Decimal.t() | nil,
          amount: Decimal.t() | nil,
          currency: String.t() | nil,
          transaction_date: DateTime.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "portfolio_transactions" do
    belongs_to :asset, Asset
    field :action, :string
    field :shares, :decimal
    field :price, :decimal
    field :commission, :decimal
    field :amount, :decimal
    field :currency, :string
    field :transaction_date, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(portfolio_transaction, attrs) do
    portfolio_transaction
    |> cast(attrs, [
      :asset_id,
      :action,
      :shares,
      :price,
      :commission,
      :amount,
      :currency,
      :transaction_date
    ])
    |> validate_required([
      :asset_id,
      :action,
      :shares,
      :price,
      :commission,
      :amount,
      :currency,
      :transaction_date
    ])
    |> validate_inclusion(:action, ["buy", "sell"])
    |> validate_inclusion(:currency, Currency.supported_currencies())
    |> validate_number(:shares, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:commission, greater_than_or_equal_to: 0)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:asset_id)
  end

  def empty,
    do: %__MODULE__{
      id: nil,
      asset_id: nil,
      asset: nil,
      action: nil,
      shares: nil,
      price: nil,
      commission: nil,
      amount: nil,
      currency: nil,
      transaction_date: nil,
      inserted_at: nil,
      updated_at: nil
    }
end
