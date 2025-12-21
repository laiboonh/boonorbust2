defmodule Boonorbust2Web.PositionsController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.Dashboard
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.RealizedProfits

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filter = Map.get(params, "filter", "")
    %{id: user_id, currency: user_currency} = conn.assigns.current_user

    # Fetch raw data
    positions = PortfolioPositions.list_latest_positions(user_id, filter)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)
    realized_profits_by_type = RealizedProfits.get_totals_by_asset_and_type(user_id)

    # Delegate all transformations to contexts
    enriched_positions =
      Dashboard.enrich_positions_for_dashboard(positions, user_id, user_currency)

    converted_realized_profits_by_asset =
      Dashboard.convert_realized_profits_by_asset(realized_profits_by_asset, user_currency)

    converted_realized_profits_by_type =
      Dashboard.convert_realized_profits_by_type(realized_profits_by_type, user_currency)

    # Render
    render(conn, :index,
      positions: enriched_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits_by_asset,
      converted_realized_profits_by_type: converted_realized_profits_by_type,
      filter: filter
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
