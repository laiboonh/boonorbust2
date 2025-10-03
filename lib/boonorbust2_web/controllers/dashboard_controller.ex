defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.PortfolioPositions

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    positions = PortfolioPositions.list_latest_positions()
    render(conn, :index, positions: positions)
  end
end
