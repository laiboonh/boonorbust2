defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioPositions

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id} = conn.assigns.current_user
    positions = PortfolioPositions.list_latest_positions(user_id)
    render(conn, :index, positions: positions)
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
end
