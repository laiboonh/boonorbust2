defmodule Boonorbust2Web.AssetController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Assets
  alias Boonorbust2.Assets.Asset
  alias Helper

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    %{id: user_id} = conn.assigns.current_user
    filter = Map.get(params, "filter", "")
    assets = Boonorbust2.Assets.list_assets(filter: filter, user_id: user_id)
    render(conn, :index, assets: assets, filter: filter)
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

  @spec update_all_prices(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_all_prices(conn, _params) do
    {:ok,
     %{
       prices_success: prices_success,
       prices_errors: prices_errors,
       dividends_success: dividends_success,
       dividends_errors: dividends_errors
     }} = Assets.update_all_asset_data()

    total_errors = prices_errors + dividends_errors

    message =
      if total_errors > 0 do
        "Updated #{prices_success} prices, #{dividends_success} dividends (#{total_errors} errors)"
      else
        "Successfully updated #{prices_success} prices and #{dividends_success} dividends"
      end

    conn
    |> put_layout(false)
    |> send_resp(200, message)
  end

  @spec dividends(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dividends(conn, %{"id" => id}) do
    asset = Assets.get_asset!(id)
    dividends = Boonorbust2.Dividends.list_dividends(asset_id: asset.id)

    conn
    |> put_layout(false)
    |> render(:dividends_modal, asset: asset, dividends: dividends)
  end
end
