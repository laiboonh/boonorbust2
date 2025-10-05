defmodule Boonorbust2Web.DashboardController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.PortfolioPositions

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id} = conn.assigns.current_user
    positions = PortfolioPositions.list_latest_positions(user_id)
    render(conn, :index, positions: positions)
  end
end
