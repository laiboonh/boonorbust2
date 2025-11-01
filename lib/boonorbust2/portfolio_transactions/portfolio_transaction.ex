defmodule Boonorbust2.PortfolioTransactions.PortfolioTransaction do
  @moduledoc """
  Schema and changeset functions for portfolio transactions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Assets.Asset

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: Ecto.UUID.t() | nil,
          user: User.t() | nil,
          asset_id: integer() | nil,
          asset: Asset.t() | nil,
          action: String.t() | nil,
          quantity: Decimal.t() | nil,
          price: Money.t() | nil,
          commission: Money.t() | nil,
          amount: Money.t() | nil,
          transaction_date: DateTime.t() | nil,
          notes: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "portfolio_transactions" do
    belongs_to :user, User, type: :binary_id
    belongs_to :asset, Asset
    field :action, :string
    field :quantity, :decimal
    field :price, Money.Ecto.Composite.Type
    field :commission, Money.Ecto.Composite.Type
    field :amount, Money.Ecto.Composite.Type
    field :transaction_date, :utc_datetime
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(portfolio_transaction, attrs) do
    # Get currency from attrs (for CSV import) or fallback to asset's currency (for forms)
    provided_currency = Map.get(attrs, "currency") || Map.get(attrs, :currency)
    asset_id = Map.get(attrs, "asset_id") || Map.get(attrs, :asset_id)

    currency = provided_currency || get_asset_currency(asset_id)

    attrs = convert_money_params(attrs, currency)

    portfolio_transaction
    |> cast(attrs, [
      :user_id,
      :asset_id,
      :action,
      :quantity,
      :price,
      :commission,
      :transaction_date,
      :notes
    ])
    |> validate_required([
      :user_id,
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
    |> validate_currency_matches_asset()
    |> calculate_amount()
    |> foreign_key_constraint(:user_id)
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

  defp get_asset_currency(nil), do: nil

  defp get_asset_currency(asset_id) do
    case Boonorbust2.Repo.get(Asset, asset_id) do
      nil -> nil
      %Asset{currency: currency} -> currency
    end
  end

  defp convert_money_params(attrs, currency) do
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

  defp validate_currency_matches_asset(changeset) do
    asset_id = get_field(changeset, :asset_id)
    price = get_field(changeset, :price)

    with true <- asset_id != nil,
         true <- price != nil,
         %Money{} <- price,
         %Asset{currency: asset_currency} <- Boonorbust2.Repo.get(Asset, asset_id) do
      transaction_currency = Money.to_currency_code(price) |> Atom.to_string()

      if transaction_currency == asset_currency do
        changeset
      else
        add_error(
          changeset,
          :price,
          "currency (#{transaction_currency}) must match asset currency (#{asset_currency})"
        )
      end
    else
      _ -> changeset
    end
  end

  def empty,
    do: %__MODULE__{
      id: nil,
      user_id: nil,
      user: nil,
      asset_id: nil,
      asset: nil,
      action: nil,
      quantity: nil,
      price: nil,
      commission: nil,
      amount: nil,
      transaction_date: nil,
      notes: nil,
      inserted_at: nil,
      updated_at: nil
    }
end
