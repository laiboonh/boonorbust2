defmodule Boonorbust2.RealizedProfits do
  @moduledoc """
  Context module for managing realized profits.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Dividends.Dividend
  alias Boonorbust2.PortfolioPositions.PortfolioPosition
  alias Boonorbust2.RealizedProfits.RealizedProfit
  alias Boonorbust2.Repo

  @spec upsert_realized_profit(map()) ::
          {:ok, RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  def upsert_realized_profit(attrs) do
    %RealizedProfit{}
    |> RealizedProfit.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:amount, :updated_at]},
      conflict_target: :portfolio_transaction_id
    )
  end

  @spec get_realized_profit_by_transaction(integer()) :: RealizedProfit.t() | nil
  def get_realized_profit_by_transaction(portfolio_transaction_id) do
    from(rp in RealizedProfit,
      where: rp.portfolio_transaction_id == ^portfolio_transaction_id
    )
    |> Repo.one()
  end

  @spec list_realized_profits_by_user(String.t()) :: [RealizedProfit.t()]
  def list_realized_profits_by_user(user_id) do
    from(rp in RealizedProfit,
      where: rp.user_id == ^user_id,
      order_by: [desc: rp.inserted_at],
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.all()
  end

  @spec list_realized_profits_by_asset(integer(), String.t()) :: [RealizedProfit.t()]
  def list_realized_profits_by_asset(asset_id, user_id) do
    from(rp in RealizedProfit,
      where: rp.asset_id == ^asset_id and rp.user_id == ^user_id,
      order_by: [desc: rp.inserted_at],
      preload: [:portfolio_transaction, :dividend]
    )
    |> Repo.all()
  end

  @spec delete_realized_profit(RealizedProfit.t()) ::
          {:ok, RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  def delete_realized_profit(%RealizedProfit{} = realized_profit) do
    Repo.delete(realized_profit)
  end

  @doc """
  Calculates the total realized profit from a list of realized profits.
  Returns the sum of all amounts.
  """
  @spec calculate_total([RealizedProfit.t()]) :: Money.t()
  def calculate_total([]), do: Money.new(:SGD, 0)

  def calculate_total([first | rest]) do
    Enum.reduce(rest, first.amount, fn rp, acc ->
      {:ok, sum} = Money.add(acc, rp.amount)
      sum
    end)
  end

  @doc """
  Calculates the total realized profit for a user across all assets.
  """
  @spec calculate_total_by_user(String.t()) :: Money.t()
  def calculate_total_by_user(user_id) do
    user_id
    |> list_realized_profits_by_user()
    |> calculate_total()
  end

  @doc """
  Returns a map of asset_id => total realized profit for all assets owned by a user.
  """
  @spec get_totals_by_asset(String.t()) :: %{integer() => Money.t()}
  def get_totals_by_asset(user_id) do
    user_id
    |> list_realized_profits_by_user()
    |> Enum.group_by(& &1.asset_id)
    |> Map.new(fn {asset_id, profits} ->
      {asset_id, calculate_total(profits)}
    end)
  end

  @doc """
  Returns separate totals for transaction-based and dividend-based realized profits by asset.
  Returns a map of asset_id => %{capital_gains: Money.t(), dividend_income: Money.t()}
  """
  @spec get_totals_by_asset_and_type(String.t()) :: %{
          integer() => %{capital_gains: Money.t(), dividend_income: Money.t()}
        }
  def get_totals_by_asset_and_type(user_id) do
    user_id
    |> list_realized_profits_by_user()
    |> Enum.group_by(& &1.asset_id)
    |> Map.new(fn {asset_id, profits} ->
      transaction_profits = Enum.filter(profits, fn rp -> rp.portfolio_transaction_id != nil end)
      dividend_profits = Enum.filter(profits, fn rp -> rp.dividend_id != nil end)

      capital_gains =
        if Enum.empty?(transaction_profits),
          do: Money.new(:SGD, 0),
          else: calculate_total(transaction_profits)

      dividend_income =
        if Enum.empty?(dividend_profits),
          do: Money.new(:SGD, 0),
          else: calculate_total(dividend_profits)

      {asset_id, %{capital_gains: capital_gains, dividend_income: dividend_income}}
    end)
  end

  @doc """
  Processes a dividend and creates realized profit records for all users who held the asset before the ex-date.

  For each user who had a position with quantity_on_hand > 0 before the dividend ex-date:
  - Calculates the dividend amount: quantity_on_hand * dividend value
  - Creates a realized profit record with dividend_id

  Returns {:ok, count} where count is the number of realized profit records created.
  """
  @spec process_dividend_for_all_users(Dividend.t()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def process_dividend_for_all_users(%Dividend{} = dividend) do
    # Convert dividend date to DateTime for comparison with transaction_date
    dividend_datetime = DateTime.new!(dividend.date, ~T[00:00:00], "Etc/UTC")

    # Get the latest position for each user before the ex-date
    # Using a subquery to find the max transaction_date and max id for each user
    latest_positions_subquery =
      from(pp in PortfolioPosition,
        join: pt in assoc(pp, :portfolio_transaction),
        where: pp.asset_id == ^dividend.asset_id and pt.transaction_date < ^dividend_datetime,
        group_by: pp.user_id,
        select: %{
          user_id: pp.user_id,
          max_transaction_date: max(pt.transaction_date),
          max_id: max(pp.id)
        }
      )

    # Get positions that match the latest for each user and have quantity > 0
    positions =
      from(pp in PortfolioPosition,
        join: pt in assoc(pp, :portfolio_transaction),
        join: lp in subquery(latest_positions_subquery),
        on: pp.user_id == lp.user_id and pt.transaction_date == lp.max_transaction_date,
        where: pp.asset_id == ^dividend.asset_id and pp.quantity_on_hand > 0,
        preload: [:portfolio_transaction]
      )
      |> Repo.all()

    # For each position, create a realized profit record
    results =
      Enum.map(positions, fn position ->
        create_dividend_realized_profit(dividend, position)
      end)

    # Count successes
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)

    {:ok, success_count}
  end

  # Creates a realized profit record for a dividend and a specific user position.
  # Calculates the dividend amount: quantity_on_hand * dividend value * (1 - withholding_tax)
  @spec create_dividend_realized_profit(Dividend.t(), PortfolioPosition.t()) ::
          {:ok, RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  defp create_dividend_realized_profit(%Dividend{} = dividend, %PortfolioPosition{} = position) do
    # Load the asset to get withholding tax rate
    dividend_with_asset = Repo.preload(dividend, :asset)
    asset = dividend_with_asset.asset

    # Calculate gross dividend: quantity_on_hand * dividend value
    dividend_value = Money.new(dividend.currency, dividend.value)
    {:ok, gross_dividend} = Money.mult(dividend_value, position.quantity_on_hand)

    # Apply withholding tax if present
    net_dividend =
      if asset.dividend_withholding_tax do
        # Calculate net amount: gross_dividend * (1 - withholding_tax)
        withholding_rate = asset.dividend_withholding_tax
        net_rate = Decimal.sub(Decimal.new(1), withholding_rate)
        {:ok, net_amount} = Money.mult(gross_dividend, net_rate)
        net_amount
      else
        gross_dividend
      end

    attrs = %{
      user_id: position.user_id,
      asset_id: position.asset_id,
      dividend_id: dividend.id,
      amount: net_dividend
    }

    # Check if a realized profit already exists for this user and dividend
    case get_realized_profit_by_dividend(position.user_id, dividend.id) do
      nil ->
        # Insert new record
        %RealizedProfit{}
        |> RealizedProfit.changeset(attrs)
        |> Repo.insert()

      existing ->
        # Update existing record
        existing
        |> RealizedProfit.changeset(attrs)
        |> Repo.update()
    end
  end

  @spec get_realized_profit_by_dividend(String.t(), integer()) :: RealizedProfit.t() | nil
  defp get_realized_profit_by_dividend(user_id, dividend_id) do
    from(rp in RealizedProfit,
      where: rp.user_id == ^user_id and rp.dividend_id == ^dividend_id
    )
    |> Repo.one()
  end

  @doc """
  Gets dividend-based realized profits grouped by month/year and asset for chart visualization.

  Returns a list of maps with:
  - month: the month/year (e.g., "2025-01")
  - asset_name: the asset name
  - amount: the Money.t() aggregated amount for that asset in that month
  - currency: the currency of the amount

  Results are sorted by month (descending) and limited to recent months.
  """
  @spec get_dividend_chart_data(String.t(), keyword()) :: [map()]
  def get_dividend_chart_data(user_id, opts \\ []) do
    days = Keyword.get(opts, :days, 365)
    cutoff_date = Date.add(Date.utc_today(), -days)

    # Query all realized profits with dividends in the date range
    realized_profits =
      from(rp in RealizedProfit,
        join: d in assoc(rp, :dividend),
        join: a in assoc(rp, :asset),
        where:
          rp.user_id == ^user_id and
            not is_nil(rp.dividend_id) and
            d.date >= ^cutoff_date,
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", d.date),
          asset_name: a.name,
          amount: rp.amount
        },
        order_by: [desc: fragment("to_char(?, 'YYYY-MM')", d.date), asc: a.name]
      )
      |> Repo.all()

    # Group and sum amounts in Elixir
    realized_profits
    |> Enum.group_by(&{&1.month, &1.asset_name})
    |> Enum.map(fn {{month, asset_name}, items} ->
      # Sum all amounts for this month/asset combination
      total_amount =
        items
        |> Enum.map(& &1.amount)
        |> Enum.reduce(fn money, acc -> Money.add!(acc, money) end)

      %{
        month: month,
        asset_name: asset_name,
        amount: total_amount.amount,
        currency: Money.to_currency_code(total_amount) |> Atom.to_string()
      }
    end)
    |> Enum.sort_by(&{&1.month, &1.asset_name}, :desc)
  end
end
