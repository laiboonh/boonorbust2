defmodule Boonorbust2.RealizedProfits.RealizedProfit do
  @moduledoc """
  Schema and changeset functions for realized profits.
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
          amount: Money.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "realized_profits" do
    belongs_to :user, User, type: :binary_id
    belongs_to :asset, Asset
    belongs_to :portfolio_transaction, PortfolioTransaction
    field :amount, Money.Ecto.Composite.Type

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(realized_profit, attrs) do
    attrs = convert_money_params(attrs)

    realized_profit
    |> cast(attrs, [:user_id, :asset_id, :portfolio_transaction_id, :amount])
    |> validate_required([:user_id, :asset_id, :portfolio_transaction_id, :amount])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:portfolio_transaction_id)
  end

  defp convert_money_params(attrs) do
    # Get the currency from the top-level currency field
    currency = Map.get(attrs, "currency") || Map.get(attrs, :currency)

    convert_money_field(attrs, :amount, currency)
  end

  defp convert_money_field(attrs, field, currency) do
    field_key = to_string(field)

    case Map.get(attrs, field_key) do
      # Already a Money struct
      %Money{} = money ->
        Map.put(attrs, field_key, money)

      # Nested map with amount and currency
      %{"amount" => amount, "currency" => curr} ->
        Map.put(attrs, field_key, Money.new(curr, amount))

      %{amount: amount, currency: curr} ->
        Map.put(attrs, field_key, Money.new(curr, amount))

      # Just an amount - use the currency from the form
      amount when currency != nil ->
        Map.put(attrs, field_key, Money.new(currency, amount))

      _ ->
        attrs
    end
  end
end
