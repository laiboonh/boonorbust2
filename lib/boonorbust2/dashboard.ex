defmodule Boonorbust2.Dashboard do
  @moduledoc """
  Context module for dashboard-specific calculations and data preparation.

  This module handles all business logic related to the dashboard display,
  including position enrichment, chart data calculations, and data conversions.
  """

  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.Portfolios
  alias Boonorbust2.PortfolioSnapshots
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Tags

  # ============================================================================
  # Types
  # ============================================================================

  @type enriched_position :: map()

  @type dashboard_data :: %{
          positions: [enriched_position()],
          realized_profits_by_asset: %{integer() => Money.t()},
          converted_realized_profits_by_asset: %{integer() => Money.t()},
          all_tags: [map()],
          tag_chart_data: [%{label: String.t(), value: float()}],
          portfolios: [map()],
          user_currency: String.t(),
          portfolio_snapshots: [map()],
          dividend_chart_data: %{
            labels: [String.t()],
            datasets: [map()],
            avg_monthly_income: float()
          },
          upcoming_dividends: [map()],
          recent_dividends: [map()],
          investment_allocation_chart_data: [map()]
        }

  @type positions_data :: %{
          positions: [enriched_position()],
          realized_profits_by_asset: %{integer() => Money.t()},
          converted_realized_profits_by_asset: %{integer() => Money.t()},
          converted_realized_profits_by_type: %{
            integer() => %{capital_gains: Money.t(), dividend_income: Money.t()}
          }
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Loads all data needed to render the dashboard page in a single call.

  Orchestrates fetching from multiple contexts, enriches positions, saves the
  daily Portfolio Snapshot (before fetching the snapshot list so today's value
  is always included), and prepares all chart data.

  Returns a map of assigns ready to be spread onto the LiveView socket.
  """
  @spec load_dashboard_data(String.t(), String.t()) :: dashboard_data()
  def load_dashboard_data(user_id, user_currency)
      when is_binary(user_id) and is_binary(user_currency) do
    positions = PortfolioPositions.list_latest_positions(user_id, nil)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)
    all_tags = Tags.list_tags(user_id)
    portfolios = Portfolios.list_portfolios(user_id)
    upcoming_dividends = RealizedProfits.list_upcoming_dividend_payments(user_id)
    recent_dividends = RealizedProfits.list_recent_dividend_payments(user_id)

    enriched_positions = enrich_positions_for_dashboard(positions, user_id, user_currency)

    converted_realized_profits =
      convert_realized_profits_by_asset(realized_profits_by_asset, user_currency)

    total_portfolio_value =
      PortfolioPositions.calculate_total_portfolio_value(enriched_positions, user_currency)

    # Snapshot must be saved before fetching so today's value is always present in the chart
    PortfolioPositions.save_portfolio_snapshot(user_id, total_portfolio_value)
    portfolio_snapshots = PortfolioSnapshots.list_snapshots(user_id, days: 90)

    %{
      positions: enriched_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits,
      all_tags: all_tags,
      tag_chart_data: calculate_tag_chart_data(enriched_positions),
      portfolios: enrich_portfolios_with_chart_data(portfolios, enriched_positions),
      user_currency: user_currency,
      portfolio_snapshots: portfolio_snapshots,
      dividend_chart_data: prepare_dividend_chart_data(user_id, user_currency),
      upcoming_dividends: convert_dividends_to_user_currency(upcoming_dividends, user_currency),
      recent_dividends: convert_dividends_to_user_currency(recent_dividends, user_currency),
      investment_allocation_chart_data:
        calculate_investment_allocation_data(enriched_positions, total_portfolio_value)
    }
  end

  @doc """
  Loads all data needed to render the positions page in a single call.

  Supports filtering positions by asset name or Tag name.

  Returns a map of assigns ready to be spread onto the LiveView socket.
  """
  @spec load_positions_data(String.t(), String.t(), String.t() | nil) :: positions_data()
  def load_positions_data(user_id, user_currency, filter \\ nil)
      when is_binary(user_id) and is_binary(user_currency) do
    positions = PortfolioPositions.list_latest_positions(user_id, filter)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)
    realized_profits_by_type = RealizedProfits.get_totals_by_asset_and_type(user_id)

    %{
      positions: enrich_positions_for_dashboard(positions, user_id, user_currency),
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset:
        convert_realized_profits_by_asset(realized_profits_by_asset, user_currency),
      converted_realized_profits_by_type:
        convert_realized_profits_by_type(realized_profits_by_type, user_currency)
    }
  end

  @doc """
  Enriches positions with converted values, tags, and sorts by total value.

  Takes raw positions and:
  - Calculates total values using current prices
  - Converts all values to user's currency
  - Calculates unrealized profits
  - Loads tags for each asset
  - Sorts by converted total value descending

  ## Parameters
    - positions: List of PortfolioPosition structs
    - user_id: User ID for loading tags
    - user_currency: Target currency for conversions (e.g., "USD")

  ## Returns
    - List of enriched position maps with added fields:
      - :total_value
      - :unrealized_profit
      - :converted_total_value
      - :converted_total_cost
      - :converted_unrealized_profit
      - :tags
  """
  @spec enrich_positions_for_dashboard([map()], String.t(), String.t()) :: [map()]
  def enrich_positions_for_dashboard(positions, user_id, user_currency)
      when is_binary(user_id) and is_binary(user_currency) do
    asset_ids = Enum.map(positions, & &1.asset_id)
    tags_by_asset = Tags.list_tags_for_assets(asset_ids, user_id)

    positions
    |> Enum.map(&enrich_single_position(&1, tags_by_asset, user_currency))
    |> Enum.sort_by(
      fn position ->
        Decimal.to_float(position.converted_total_value.amount)
      end,
      :desc
    )
  end

  @doc """
  Converts realized profits map from {asset_id => Money} to user currency.

  ## Parameters
    - profits_by_asset: Map of asset_id => Money
    - user_currency: Target currency code

  ## Returns
    - Map of asset_id => Money (in user currency)
  """
  @spec convert_realized_profits_by_asset(map(), String.t()) :: map()
  def convert_realized_profits_by_asset(profits_by_asset, user_currency)
      when is_binary(user_currency) do
    profits_by_asset
    |> Enum.map(fn {asset_id, profit} ->
      {asset_id, ExchangeRates.convert_money(profit, user_currency)}
    end)
    |> Map.new()
  end

  @doc """
  Converts realized profits map separated by type to user currency.

  ## Parameters
    - profits_by_type: Map of asset_id => %{capital_gains: Money, dividend_income: Money}
    - user_currency: Target currency code

  ## Returns
    - Map of asset_id => %{capital_gains: Money, dividend_income: Money} (in user currency)
  """
  @spec convert_realized_profits_by_type(map(), String.t()) :: map()
  def convert_realized_profits_by_type(profits_by_type, user_currency)
      when is_binary(user_currency) do
    profits_by_type
    |> Enum.map(fn {asset_id, %{capital_gains: cg, dividend_income: di}} ->
      {asset_id,
       %{
         capital_gains: ExchangeRates.convert_money(cg, user_currency),
         dividend_income: ExchangeRates.convert_money(di, user_currency)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Converts dividend records to user currency by adding :converted_amount field.

  ## Parameters
    - dividends: List of dividend maps
    - user_currency: Target currency code

  ## Returns
    - List of dividend maps with :converted_amount field added
  """
  @spec convert_dividends_to_user_currency([map()], String.t()) :: [map()]
  def convert_dividends_to_user_currency(dividends, user_currency)
      when is_binary(user_currency) do
    Enum.map(dividends, fn dividend ->
      converted_amount = ExchangeRates.convert_money(dividend.amount, user_currency)
      Map.put(dividend, :converted_amount, converted_amount)
    end)
  end

  @doc """
  Calculates tag chart data (pie chart) aggregating position values by tag.

  ## Parameters
    - enriched_positions: List of positions with :converted_total_value and :tags

  ## Returns
    - List of %{label: tag_name, value: float} sorted by value descending
  """
  @spec calculate_tag_chart_data([map()]) :: [map()]
  def calculate_tag_chart_data(enriched_positions) do
    enriched_positions
    |> aggregate_values_by_tag()
    |> sort_and_format_chart_data()
  end

  @doc """
  Calculates portfolio chart data for a specific portfolio.

  ## Parameters
    - tags: List of tags belonging to the portfolio
    - enriched_positions: List of enriched positions

  ## Returns
    - List of %{label: tag_name, value: float} for tags with non-zero values
  """
  @spec calculate_portfolio_chart_data([map()], [map()]) :: [map()]
  def calculate_portfolio_chart_data(tags, enriched_positions) do
    tags
    |> Enum.map(&build_tag_chart_item(&1, enriched_positions))
    |> Enum.filter(&(&1.value > 0))
    |> Enum.sort_by(& &1.value, :desc)
  end

  @doc """
  Prepares dividend chart data for the last 24 months.

  Gets dividend data from RealizedProfits, converts to user currency,
  and formats for charting library (labels + datasets by asset).

  ## Parameters
    - user_id: User ID
    - user_currency: Target currency for conversion

  ## Returns
    - Map with :labels (months) and :datasets (one per asset)
  """
  @spec prepare_dividend_chart_data(String.t(), String.t()) :: %{
          labels: [String.t()],
          datasets: [map()],
          avg_monthly_income: float()
        }
  def prepare_dividend_chart_data(user_id, user_currency)
      when is_binary(user_id) and is_binary(user_currency) do
    # Get dividend data for the last 24 months (approximately 730 days)
    raw_data = RealizedProfits.get_dividend_chart_data(user_id, days: 730)

    # Convert all amounts to user's currency
    converted_data = convert_dividend_data_to_currency(raw_data, user_currency)

    # Get unique months and assets
    months = converted_data |> Enum.map(& &1.month) |> Enum.uniq() |> Enum.sort()
    assets = converted_data |> Enum.map(& &1.asset_name) |> Enum.uniq() |> Enum.sort()

    # Build datasets: one dataset per asset
    datasets = build_dividend_datasets(assets, months, converted_data)

    avg_monthly_income = calculate_avg_monthly_income(converted_data, months)

    %{
      labels: months,
      datasets: datasets,
      avg_monthly_income: avg_monthly_income
    }
  end

  @doc """
  Calculates investment allocation percentages for each position.

  ## Parameters
    - enriched_positions: List of positions with :converted_total_value
    - total_portfolio_value: Total portfolio value Money

  ## Returns
    - List of %{label: asset_name, value: float, percentage: float} sorted by percentage
  """
  @spec calculate_investment_allocation_data([map()], Money.t()) :: [map()]
  def calculate_investment_allocation_data(enriched_positions, total_portfolio_value) do
    total_value_float = Decimal.to_float(total_portfolio_value.amount)

    enriched_positions
    |> Enum.map(fn position ->
      position_value = Decimal.to_float(position.converted_total_value.amount)

      percentage =
        if total_value_float > 0 do
          (position_value / total_value_float * 100)
          |> Float.round(2)
        else
          0.0
        end

      %{
        label: position.asset.name,
        value: position_value,
        percentage: percentage
      }
    end)
    |> Enum.filter(&(&1.percentage > 0))
    |> Enum.sort_by(& &1.percentage, :desc)
  end

  @doc """
  Enriches portfolios with their respective chart data.

  ## Parameters
    - portfolios: List of portfolio structs
    - enriched_positions: List of enriched positions

  ## Returns
    - List of portfolios with :tags and :chart_data fields added
  """
  @spec enrich_portfolios_with_chart_data([map()], [map()]) :: [map()]
  def enrich_portfolios_with_chart_data(portfolios, enriched_positions) do
    Enum.map(portfolios, fn portfolio ->
      tags = Portfolios.list_tags_for_portfolio(portfolio.id)
      chart_data = calculate_portfolio_chart_data(tags, enriched_positions)

      portfolio
      |> Map.put(:tags, tags)
      |> Map.put(:chart_data, chart_data)
    end)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  # Enriches a single position with converted values and tags
  defp enrich_single_position(position, tags_by_asset, user_currency) do
    {total_value, unrealized_profit} =
      if position.asset.price do
        tv =
          Money.new!(
            Decimal.mult(position.quantity_on_hand, position.asset.price),
            position.amount_on_hand.currency
          )

        {:ok, up} = Money.sub(tv, position.amount_on_hand)
        {tv, up}
      else
        {nil, nil}
      end

    converted_total_value =
      ExchangeRates.convert_money(total_value || position.amount_on_hand, user_currency)

    converted_total_cost =
      ExchangeRates.convert_money(position.amount_on_hand, user_currency)

    converted_unrealized_profit =
      if position.asset.price do
        {:ok, profit} = Money.sub(converted_total_value, converted_total_cost)
        profit
      else
        nil
      end

    tags = Map.get(tags_by_asset, position.asset_id, [])

    # Pre-compute "show native alongside converted" flags so the template doesn't
    # repeat the currency-comparison logic for each field
    show_converted_cost =
      Money.to_currency_code(converted_total_cost) !=
        Money.to_currency_code(position.amount_on_hand)

    show_converted_value =
      total_value != nil &&
        Money.to_currency_code(converted_total_value) !=
          Money.to_currency_code(total_value)

    show_converted_unrealized =
      unrealized_profit != nil &&
        Money.to_currency_code(converted_unrealized_profit) !=
          Money.to_currency_code(unrealized_profit)

    position
    |> Map.put(:total_value, total_value)
    |> Map.put(:unrealized_profit, unrealized_profit)
    |> Map.put(:converted_total_value, converted_total_value)
    |> Map.put(:converted_total_cost, converted_total_cost)
    |> Map.put(:converted_unrealized_profit, converted_unrealized_profit)
    |> Map.put(:show_converted_cost, show_converted_cost)
    |> Map.put(:show_converted_value, show_converted_value)
    |> Map.put(:show_converted_unrealized, show_converted_unrealized)
    |> Map.put(:tags, tags)
  end

  # Aggregates position values by their tags
  defp aggregate_values_by_tag(positions) do
    Enum.reduce(positions, %{}, fn position, acc ->
      value_amount = Decimal.to_float(position.converted_total_value.amount)
      tags = Map.get(position, :tags, [])

      add_value_to_tags(acc, tags, value_amount)
    end)
  end

  # Adds value to tags, or to "Untagged" if no tags
  defp add_value_to_tags(acc, [], value_amount) do
    Map.update(acc, "Untagged", value_amount, &(&1 + value_amount))
  end

  defp add_value_to_tags(acc, tags, value_amount) do
    Enum.reduce(tags, acc, fn tag, inner_acc ->
      Map.update(inner_acc, tag.name, value_amount, &(&1 + value_amount))
    end)
  end

  # Sorts tag values and formats for chart display
  defp sort_and_format_chart_data(tag_values) do
    tag_values
    |> Enum.sort_by(fn {_tag, value} -> value end, :desc)
    |> Enum.map(fn {tag, value} -> %{label: tag, value: value} end)
  end

  # Builds a chart item for a single tag
  defp build_tag_chart_item(tag, sorted_positions) do
    positions_with_tag = filter_positions_by_tag(sorted_positions, tag.id)
    total_value = sum_position_values(positions_with_tag)

    %{
      label: tag.name,
      value: total_value
    }
  end

  # Filters positions that have a specific tag
  defp filter_positions_by_tag(positions, tag_id) do
    Enum.filter(positions, fn position ->
      position_tag_ids = Enum.map(Map.get(position, :tags, []), & &1.id)
      tag_id in position_tag_ids
    end)
  end

  # Sums the converted total values of positions
  defp sum_position_values(positions) do
    positions
    |> Enum.reduce(Decimal.new(0), fn position, acc ->
      Decimal.add(acc, position.converted_total_value.amount)
    end)
    |> Decimal.to_float()
  end

  # Converts dividend data to user currency
  defp convert_dividend_data_to_currency(raw_data, user_currency) do
    Enum.map(raw_data, fn item ->
      money = Money.new!(item.amount, item.currency)
      converted_money = ExchangeRates.convert_money(money, user_currency)

      %{
        month: item.month,
        asset_name: item.asset_name,
        amount: Decimal.to_float(converted_money.amount)
      }
    end)
  end

  # Builds datasets for dividend chart (one per asset)
  defp build_dividend_datasets(assets, months, converted_data) do
    Enum.map(assets, fn asset_name ->
      data = get_asset_amounts_by_month(asset_name, months, converted_data)

      %{
        label: asset_name,
        data: data
      }
    end)
  end

  # Gets amounts for an asset across all months
  defp get_asset_amounts_by_month(asset_name, months, converted_data) do
    Enum.map(months, fn month ->
      find_amount_for_asset_month(asset_name, month, converted_data)
    end)
  end

  # Finds the amount for a specific asset and month (0.0 if not found)
  defp find_amount_for_asset_month(asset_name, month, converted_data) do
    case Enum.find(converted_data, fn item ->
           item.month == month && item.asset_name == asset_name
         end) do
      nil -> 0.0
      item -> item.amount
    end
  end

  # Calculates average monthly dividend income across all months
  defp calculate_avg_monthly_income(_converted_data, []), do: 0.0

  defp calculate_avg_monthly_income(converted_data, months) do
    total = Enum.reduce(converted_data, 0.0, fn item, acc -> acc + item.amount end)
    total / length(months)
  end
end
