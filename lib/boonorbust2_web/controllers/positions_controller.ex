defmodule Boonorbust2Web.PositionsController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.PortfolioPositions
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

    render(conn, :index,
      positions: sorted_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits_by_asset
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
end
