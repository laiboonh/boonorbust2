defmodule Boonorbust2.PortfolioTransactions.PortfolioTransaction do
  @moduledoc """
  Schema and changeset functions for portfolio transactions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Assets.Asset

  @type t :: %__MODULE__{
          id: integer() | nil,
          asset_id: integer() | nil,
          asset: Asset.t() | nil,
          action: String.t() | nil,
          quantity: Decimal.t() | nil,
          price: Money.t() | nil,
          commission: Money.t() | nil,
          amount: Money.t() | nil,
          transaction_date: DateTime.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "portfolio_transactions" do
    belongs_to :asset, Asset
    field :action, :string
    field :quantity, :decimal
    field :price, Money.Ecto.Composite.Type
    field :commission, Money.Ecto.Composite.Type
    field :amount, Money.Ecto.Composite.Type
    field :transaction_date, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(portfolio_transaction, attrs) do
    attrs = convert_money_params(attrs)

    portfolio_transaction
    |> cast(attrs, [
      :asset_id,
      :action,
      :quantity,
      :price,
      :commission,
      :transaction_date
    ])
    |> validate_required([
      :asset_id,
      :action,
      :quantity,
      :price,
      :commission,
      :transaction_date
    ])
    |> validate_inclusion(:action, ["buy", "sell"])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_money(:price)
    |> validate_money(:commission, greater_than_or_equal_to: 0)
    |> calculate_amount()
    |> foreign_key_constraint(:asset_id)
  end

  defp calculate_amount(changeset) do
    quantity = get_field(changeset, :quantity)
    price = get_field(changeset, :price)
    commission = get_field(changeset, :commission)

    case {quantity, price, commission} do
      {%Decimal{} = qty, %Money{} = p, %Money{} = comm} ->
        # Calculate: (quantity * price) + commission
        with {:ok, subtotal} <- Money.mult(p, qty),
             {:ok, total} <- Money.add(subtotal, comm) do
          put_change(changeset, :amount, total)
        else
          {:error, _} -> changeset
        end

      _ ->
        changeset
    end
  end

  defp convert_money_params(attrs) do
    # Get the currency from the top-level currency field
    currency = Map.get(attrs, "currency") || Map.get(attrs, :currency)

    attrs
    |> convert_money_field(:price, currency)
    |> convert_money_field(:commission, currency)

    # Amount will be calculated, not converted from params
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

  defp validate_money(changeset, field, opts \\ []) do
    case get_field(changeset, field) do
      %Money{amount: amount} ->
        min = Keyword.get(opts, :greater_than_or_equal_to, nil)

        if min && Decimal.compare(amount, min) == :lt do
          add_error(changeset, field, "must be greater than or equal to #{min}")
        else
          changeset
        end

      nil ->
        changeset

      _ ->
        add_error(changeset, field, "must be a valid Money amount")
    end
  end

  def empty,
    do: %__MODULE__{
      id: nil,
      asset_id: nil,
      asset: nil,
      action: nil,
      quantity: nil,
      price: nil,
      commission: nil,
      amount: nil,
      transaction_date: nil,
      inserted_at: nil,
      updated_at: nil
    }
end
