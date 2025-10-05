defmodule Boonorbust2.PortfolioPositions.PortfolioPosition do
  @moduledoc """
  Schema and changeset functions for portfolio positions.
  Tracks the running position (average price and quantity on hand) for each asset.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | nil,
          asset_id: integer() | nil,
          asset: Asset.t() | nil,
          portfolio_transaction_id: integer() | nil,
          portfolio_transaction: PortfolioTransaction.t() | nil,
          average_price: Money.t() | nil,
          quantity_on_hand: Decimal.t() | nil,
          amount_on_hand: Money.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "portfolio_positions" do
    belongs_to :user, User, type: :binary_id
    belongs_to :asset, Asset
    belongs_to :portfolio_transaction, PortfolioTransaction
    field :average_price, Money.Ecto.Composite.Type
    field :quantity_on_hand, :decimal
    field :amount_on_hand, Money.Ecto.Composite.Type

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(portfolio_position, attrs) do
    portfolio_position
    |> cast(attrs, [
      :user_id,
      :asset_id,
      :portfolio_transaction_id,
      :average_price,
      :quantity_on_hand,
      :amount_on_hand
    ])
    |> validate_required([
      :user_id,
      :asset_id,
      :average_price,
      :quantity_on_hand,
      :amount_on_hand
    ])
    |> validate_number(:quantity_on_hand, greater_than_or_equal_to: 0)
    |> validate_money(:average_price, greater_than: 0)
    |> validate_money(:amount_on_hand, greater_than_or_equal_to: 0)
    |> unique_constraint(:portfolio_transaction_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:portfolio_transaction_id)
  end

  defp validate_money(changeset, field, opts) do
    case get_field(changeset, field) do
      %Money{amount: amount} ->
        min_exclusive = Keyword.get(opts, :greater_than, nil)
        min_inclusive = Keyword.get(opts, :greater_than_or_equal_to, nil)

        cond do
          min_exclusive && Decimal.compare(amount, min_exclusive) != :gt ->
            add_error(changeset, field, "must be greater than #{min_exclusive}")

          min_inclusive && Decimal.compare(amount, min_inclusive) == :lt ->
            add_error(changeset, field, "must be greater than or equal to #{min_inclusive}")

          true ->
            changeset
        end

      nil ->
        changeset

      _ ->
        add_error(changeset, field, "must be a valid Money amount")
    end
  end
end
