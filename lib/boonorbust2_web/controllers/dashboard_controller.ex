defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.Portfolios
  alias Boonorbust2.PortfolioSnapshots
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Tags

  require Logger

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id, currency: user_currency} = conn.assigns.current_user
    positions = PortfolioPositions.list_latest_positions(user_id, nil)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)

    # Convert realized profits to user's preferred currency
    converted_realized_profits_by_asset =
      realized_profits_by_asset
      |> Enum.map(fn {asset_id, profit} ->
        {asset_id, convert_to_user_currency(profit, user_currency)}
      end)
      |> Map.new()

    # Add converted values to positions and sort by converted total value (descending)
    positions_with_converted_values =
      Enum.map(positions, fn position ->
        total_value =
          if position.asset.price do
            Money.new!(
              Decimal.mult(position.quantity_on_hand, position.asset.price),
              position.amount_on_hand.currency
            )
          else
            position.amount_on_hand
          end

        # Convert to user's preferred currency
        converted_total_value = convert_to_user_currency(total_value, user_currency)
        converted_total_cost = convert_to_user_currency(position.amount_on_hand, user_currency)

        # Calculate converted unrealized profit
        converted_unrealized_profit =
          if position.asset.price do
            {:ok, profit} = Money.sub(converted_total_value, converted_total_cost)
            profit
          else
            nil
          end

        # Load tags for this asset
        tags = Tags.list_tags_for_asset(position.asset_id, user_id)

        # Add converted values to position for display
        position
        |> Map.put(:converted_total_value, converted_total_value)
        |> Map.put(:converted_total_cost, converted_total_cost)
        |> Map.put(:converted_unrealized_profit, converted_unrealized_profit)
        |> Map.put(:tags, tags)
      end)

    sorted_positions =
      Enum.sort_by(
        positions_with_converted_values,
        fn position ->
          Decimal.to_float(position.converted_total_value.amount)
        end,
        :desc
      )

    all_tags = Tags.list_tags(user_id)

    # Calculate total portfolio value and save snapshot
    total_portfolio_value = calculate_total_portfolio_value(sorted_positions, user_currency)
    save_portfolio_snapshot(user_id, total_portfolio_value)

    # Calculate tag value aggregations for pie chart
    tag_chart_data = calculate_tag_chart_data(sorted_positions)

    # Load portfolios and calculate chart data for each
    portfolios = Portfolios.list_portfolios(user_id)

    portfolios_with_chart_data =
      Enum.map(portfolios, fn portfolio ->
        tags = Portfolios.list_tags_for_portfolio(portfolio.id)
        chart_data = calculate_portfolio_chart_data(tags, sorted_positions)

        portfolio
        |> Map.put(:tags, tags)
        |> Map.put(:chart_data, chart_data)
      end)

    # Load portfolio snapshots for the last 90 days for the line graph
    portfolio_snapshots = PortfolioSnapshots.list_snapshots(user_id, days: 90)

    # Load dividend chart data for the last 24 months
    dividend_chart_data = prepare_dividend_chart_data(user_id, user_currency)

    # Load upcoming dividend payments (within next 2 weeks)
    upcoming_dividends = RealizedProfits.list_upcoming_dividend_payments(user_id)

    # Convert upcoming dividends to user's currency
    upcoming_dividends_with_converted_amounts =
      Enum.map(upcoming_dividends, fn dividend ->
        converted_amount = convert_to_user_currency(dividend.amount, user_currency)
        Map.put(dividend, :converted_amount, converted_amount)
      end)

    render(conn, :index,
      positions: sorted_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits_by_asset,
      all_tags: all_tags,
      tag_chart_data: tag_chart_data,
      portfolios: portfolios_with_chart_data,
      user_currency: user_currency,
      portfolio_snapshots: portfolio_snapshots,
      dividend_chart_data: dividend_chart_data,
      upcoming_dividends: upcoming_dividends_with_converted_amounts
    )
  end

  # Private functions

  @spec convert_to_user_currency(Money.t(), String.t()) :: Money.t()
  defp convert_to_user_currency(money, target_currency) do
    source_currency = money |> Money.to_currency_code() |> Atom.to_string()

    # If already in target currency, return as-is
    if source_currency == target_currency do
      money
    else
      # Get exchange rate and convert
      case ExchangeRates.get_rate(source_currency, target_currency) do
        {:ok, rate} ->
          converted_amount = Decimal.mult(money.amount, Decimal.from_float(rate))
          Money.new!(converted_amount, target_currency)

        {:error, reason} ->
          Logger.warning(
            "Failed to get exchange rate from #{source_currency} to #{target_currency}: #{inspect(reason)}. Using original currency."
          )

          # Fallback: return original money if exchange rate fetch fails
          money
      end
    end
  end

  @spec calculate_tag_chart_data([map()]) :: [map()]
  defp calculate_tag_chart_data(positions) do
    positions
    |> aggregate_values_by_tag()
    |> sort_and_format_chart_data()
  end

  @spec aggregate_values_by_tag([map()]) :: %{String.t() => float()}
  defp aggregate_values_by_tag(positions) do
    Enum.reduce(positions, %{}, fn position, acc ->
      value_amount = Decimal.to_float(position.converted_total_value.amount)
      tags = Map.get(position, :tags, [])

      add_value_to_tags(acc, tags, value_amount)
    end)
  end

  @spec add_value_to_tags(map(), [map()], float()) :: map()
  defp add_value_to_tags(acc, [], value_amount) do
    Map.update(acc, "Untagged", value_amount, &(&1 + value_amount))
  end

  defp add_value_to_tags(acc, tags, value_amount) do
    Enum.reduce(tags, acc, fn tag, inner_acc ->
      Map.update(inner_acc, tag.name, value_amount, &(&1 + value_amount))
    end)
  end

  @spec sort_and_format_chart_data(%{String.t() => float()}) :: [map()]
  defp sort_and_format_chart_data(tag_values) do
    tag_values
    |> Enum.sort_by(fn {_tag, value} -> value end, :desc)
    |> Enum.map(fn {tag, value} -> %{label: tag, value: value} end)
  end

  @spec calculate_portfolio_chart_data([map()], [map()]) :: [map()]
  defp calculate_portfolio_chart_data(tags, sorted_positions) do
    tags
    |> Enum.map(&build_tag_chart_item(&1, sorted_positions))
    |> Enum.filter(&(&1.value > 0))
    |> Enum.sort_by(& &1.value, :desc)
  end

  @spec build_tag_chart_item(map(), [map()]) :: map()
  defp build_tag_chart_item(tag, sorted_positions) do
    positions_with_tag = filter_positions_by_tag(sorted_positions, tag.id)
    total_value = sum_position_values(positions_with_tag)

    %{
      label: tag.name,
      value: total_value
    }
  end

  @spec filter_positions_by_tag([map()], integer()) :: [map()]
  defp filter_positions_by_tag(positions, tag_id) do
    Enum.filter(positions, fn position ->
      position_tag_ids = Enum.map(Map.get(position, :tags, []), & &1.id)
      tag_id in position_tag_ids
    end)
  end

  @spec sum_position_values([map()]) :: float()
  defp sum_position_values(positions) do
    positions
    |> Enum.reduce(Decimal.new(0), fn position, acc ->
      Decimal.add(acc, position.converted_total_value.amount)
    end)
    |> Decimal.to_float()
  end

  @spec calculate_total_portfolio_value([map()], String.t()) :: Money.t()
  defp calculate_total_portfolio_value(positions, currency) do
    total_amount =
      positions
      |> Enum.reduce(Decimal.new(0), fn position, acc ->
        Decimal.add(acc, position.converted_total_value.amount)
      end)

    Money.new!(total_amount, currency)
  end

  @spec save_portfolio_snapshot(String.t(), Money.t()) :: :ok
  defp save_portfolio_snapshot(user_id, total_value) do
    today = Date.utc_today()

    case PortfolioSnapshots.upsert_snapshot(user_id, today, total_value) do
      {:ok, _snapshot} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Failed to save portfolio snapshot: #{inspect(changeset)}")
        :ok
    end
  end

  @spec prepare_dividend_chart_data(String.t(), String.t()) :: %{
          labels: [String.t()],
          datasets: [map()]
        }
  defp prepare_dividend_chart_data(user_id, user_currency) do
    # Get dividend data for the last 24 months (approximately 730 days)
    raw_data = RealizedProfits.get_dividend_chart_data(user_id, days: 730)

    # Convert all amounts to user's currency
    converted_data = convert_dividend_data_to_currency(raw_data, user_currency)

    # Get unique months and assets
    months = converted_data |> Enum.map(& &1.month) |> Enum.uniq() |> Enum.sort()
    assets = converted_data |> Enum.map(& &1.asset_name) |> Enum.uniq() |> Enum.sort()

    # Build datasets: one dataset per asset
    datasets = build_dividend_datasets(assets, months, converted_data)

    %{
      labels: months,
      datasets: datasets
    }
  end

  @spec convert_dividend_data_to_currency([map()], String.t()) :: [map()]
  defp convert_dividend_data_to_currency(raw_data, user_currency) do
    Enum.map(raw_data, fn item ->
      money = Money.new!(item.amount, item.currency)
      converted_money = convert_to_user_currency(money, user_currency)

      %{
        month: item.month,
        asset_name: item.asset_name,
        amount: Decimal.to_float(converted_money.amount)
      }
    end)
  end

  @spec build_dividend_datasets([String.t()], [String.t()], [map()]) :: [map()]
  defp build_dividend_datasets(assets, months, converted_data) do
    Enum.map(assets, fn asset_name ->
      data = get_asset_amounts_by_month(asset_name, months, converted_data)

      %{
        label: asset_name,
        data: data
      }
    end)
  end

  @spec get_asset_amounts_by_month(String.t(), [String.t()], [map()]) :: [float()]
  defp get_asset_amounts_by_month(asset_name, months, converted_data) do
    Enum.map(months, fn month ->
      find_amount_for_asset_month(asset_name, month, converted_data)
    end)
  end

  @spec find_amount_for_asset_month(String.t(), String.t(), [map()]) :: float()
  defp find_amount_for_asset_month(asset_name, month, converted_data) do
    case Enum.find(converted_data, fn item ->
           item.month == month && item.asset_name == asset_name
         end) do
      nil -> 0.0
      item -> item.amount
    end
  end
end
