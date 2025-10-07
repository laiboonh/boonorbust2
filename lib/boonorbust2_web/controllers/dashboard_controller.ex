defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.RealizedProfits

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id} = conn.assigns.current_user
    positions = PortfolioPositions.list_latest_positions(user_id)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)

    # Sort positions by total value (descending)
    sorted_positions =
      Enum.sort_by(
        positions,
        fn position ->
          total_value =
            if position.asset.price do
              Money.new!(
                Decimal.mult(position.quantity_on_hand, position.asset.price),
                position.amount_on_hand.currency
              )
            else
              position.amount_on_hand
            end

          Decimal.to_float(total_value.amount)
        end,
        :desc
      )

    render(conn, :index,
      positions: sorted_positions,
      realized_profits_by_asset: realized_profits_by_asset
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
end
