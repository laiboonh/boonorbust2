defmodule Boonorbust2Web.AssetController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.PortfolioPositions
  alias Helper

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    assets = Boonorbust2.Assets.list_assets()
    render(conn, :index, assets: assets)
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    asset = Assets.get_asset!(id)
    render(conn, :show, asset: asset)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Assets.change_asset(%Asset{})
    render(conn, :new, changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"asset" => asset_params}) do
    case Assets.create_asset(asset_params) do
      {:ok, asset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:asset_item, asset: asset)
        else
          redirect(conn, to: ~p"/assets")
        end

      {:error, changeset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_status(:unprocessable_entity)
          |> put_layout(false)
          |> put_view(Boonorbust2Web.CoreComponents)
          |> render(:form_errors, changeset: changeset)
        else
          render(conn, :new, changeset: changeset)
        end
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    asset = Assets.get_asset!(id)
    changeset = Assets.change_asset(asset)
    render(conn, :edit, asset: asset, changeset: changeset)
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "asset" => asset_params}) do
    asset = Assets.get_asset!(id)

    case Assets.update_asset(asset, asset_params) do
      {:ok, updated_asset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:asset_item, asset: updated_asset)
        else
          redirect(conn, to: ~p"/assets/#{updated_asset}")
        end

      {:error, changeset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_status(:unprocessable_entity)
          |> put_layout(false)
          |> put_view(Boonorbust2Web.CoreComponents)
          |> render(:form_errors, changeset: changeset)
        else
          render(conn, :edit, asset: asset, changeset: changeset)
        end
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    asset = Assets.get_asset!(id)
    {:ok, _asset} = Assets.delete_asset(asset)

    if get_req_header(conn, "hx-request") != [] do
      send_resp(conn, 200, "")
    else
      redirect(conn, to: ~p"/assets")
    end
  end

  @spec positions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def positions(conn, %{"id" => id}) do
    asset = Assets.get_asset!(id)

    # Calculate and upsert positions before fetching
    PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id)

    positions = PortfolioPositions.get_positions_for_asset(asset.id)

    conn
    |> put_layout(false)
    |> render(:positions_modal_content, asset: asset, positions: positions)
  end
end
