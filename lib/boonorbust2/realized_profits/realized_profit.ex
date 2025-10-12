defmodule Boonorbust2.RealizedProfits.RealizedProfit do
  @moduledoc """
  Schema and changeset functions for realized profits.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Dividends.Dividend
  alias Boonorbust2.PortfolioTransactions.PortfolioTransaction

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | nil,
          asset_id: integer() | nil,
          asset: Asset.t() | nil,
          portfolio_transaction_id: integer() | nil,
          portfolio_transaction: PortfolioTransaction.t() | nil,
          dividend_id: integer() | nil,
          dividend: Dividend.t() | nil,
          amount: Money.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "realized_profits" do
    belongs_to :user, User, type: :binary_id
    belongs_to :asset, Asset
    belongs_to :portfolio_transaction, PortfolioTransaction
    belongs_to :dividend, Dividend
    field :amount, Money.Ecto.Composite.Type

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(realized_profit, attrs) do
    attrs = convert_money_params(attrs)

    realized_profit
    |> cast(attrs, [:user_id, :asset_id, :portfolio_transaction_id, :dividend_id, :amount])
    |> validate_required([:user_id, :asset_id, :amount])
    |> validate_transaction_or_dividend()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:portfolio_transaction_id)
    |> foreign_key_constraint(:dividend_id)
  end

  # Validates that at least one of portfolio_transaction_id or dividend_id is set
  defp validate_transaction_or_dividend(changeset) do
    transaction_id = get_field(changeset, :portfolio_transaction_id)
    dividend_id = get_field(changeset, :dividend_id)

    cond do
      transaction_id != nil && dividend_id != nil ->
        changeset
        |> add_error(:portfolio_transaction_id, "cannot have both transaction and dividend")
        |> add_error(:dividend_id, "cannot have both transaction and dividend")

      transaction_id == nil && dividend_id == nil ->
        changeset
        |> add_error(:portfolio_transaction_id, "must have either transaction or dividend")
        |> add_error(:dividend_id, "must have either transaction or dividend")

      true ->
        changeset
    end
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
