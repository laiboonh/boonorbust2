defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.Portfolios
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Tags

  require Logger

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id, currency: user_currency} = conn.assigns.current_user
    positions = PortfolioPositions.list_latest_positions(user_id)
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

    # Calculate tag value aggregations for pie chart
    tag_chart_data = calculate_tag_chart_data(sorted_positions)

    # Load portfolios and calculate chart data for each
    portfolios = Portfolios.list_portfolios(user_id)

    portfolios_with_chart_data =
      Enum.map(portfolios, fn portfolio ->
        tags = Portfolios.list_tags_for_portfolio(portfolio.id)
        tag_ids = Enum.map(tags, & &1.id)

        # Filter positions that have any of the portfolio's tags
        portfolio_positions =
          Enum.filter(sorted_positions, fn position ->
            position_tag_ids = Enum.map(Map.get(position, :tags, []), & &1.id)
            Enum.any?(tag_ids, &(&1 in position_tag_ids))
          end)

        # Calculate chart data for this portfolio (breakdown by asset)
        chart_data =
          portfolio_positions
          |> Enum.map(fn position ->
            %{
              label: position.asset.name,
              value: Decimal.to_float(position.converted_total_value.amount)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        portfolio
        |> Map.put(:tags, tags)
        |> Map.put(:chart_data, chart_data)
      end)

    render(conn, :index,
      positions: sorted_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits_by_asset,
      all_tags: all_tags,
      tag_chart_data: tag_chart_data,
      portfolios: portfolios_with_chart_data,
      user_currency: user_currency
    )
  end

  @spec positions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def positions(conn, %{"asset_id" => asset_id}) do
    %{id: user_id} = conn.assigns.current_user
    asset = Assets.get_asset!(asset_id)

    positions = PortfolioPositions.get_positions_for_asset(asset.id, user_id)

    conn
    |> put_layout(false)
    |> render(:positions_modal_content, asset: asset, positions: positions)
  end

  @spec realized_profits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def realized_profits(conn, %{"asset_id" => asset_id}) do
    %{id: user_id} = conn.assigns.current_user
    asset = Assets.get_asset!(asset_id)

    realized_profits = RealizedProfits.list_realized_profits_by_asset(asset.id, user_id)
    total = RealizedProfits.calculate_total(realized_profits)

    conn
    |> put_layout(false)
    |> render(:realized_profits_modal_content,
      asset: asset,
      realized_profits: realized_profits,
      total: total
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
end
