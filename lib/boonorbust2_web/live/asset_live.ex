defmodule Boonorbust2Web.AssetLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Assets
  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Dividends

  @impl true
  def mount(_params, _session, socket) do
    %{id: user_id} = socket.assigns.current_user

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:filter, "")
      |> assign(:form_errors, nil)
      |> assign(:asset_in_progress, nil)
      |> assign(:dividends_modal, nil)
      |> assign(:update_result, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, reload_assets(socket)}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     assign(socket,
       asset_in_progress: %{
         id: nil,
         name: nil,
         price_url: nil,
         currency: nil,
         distributes_dividends: false,
         dividend_url: nil,
         dividend_withholding_tax: nil
       },
       form_errors: nil,
       update_result: nil
     )}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    asset = Assets.get_asset!(id)

    {:noreply,
     assign(socket,
       asset_in_progress: %{
         id: asset.id,
         name: asset.name,
         price_url: asset.price_url,
         currency: asset.currency,
         distributes_dividends: asset.distributes_dividends,
         dividend_url: asset.dividend_url,
         dividend_withholding_tax:
           if(asset.dividend_withholding_tax,
             do: asset.dividend_withholding_tax |> Decimal.normalize() |> Decimal.to_string(),
             else: nil
           )
       },
       form_errors: nil,
       update_result: nil
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, asset_in_progress: nil, form_errors: nil)}
  end

  def handle_event("save", %{"asset" => asset_params}, socket) do
    case Assets.create_asset(asset_params) do
      {:ok, asset} ->
        socket =
          socket
          |> assign(:asset_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:assets, asset, at: 0)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form_error(socket, changeset, asset_params)}
    end
  end

  def handle_event("update", %{"asset_id" => id, "asset" => asset_params}, socket) do
    asset = Assets.get_asset!(id)

    case Assets.update_asset(asset, asset_params) do
      {:ok, updated_asset} ->
        socket =
          socket
          |> assign(:asset_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:assets, updated_asset)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form_error(socket, changeset, asset_params)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    asset = Assets.get_asset!(id)
    {:ok, _} = Assets.delete_asset(asset)

    {:noreply, stream_delete(socket, :assets, %Asset{id: asset.id})}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> reload_assets()

    {:noreply, socket}
  end

  def handle_event("clear_filter", _params, socket) do
    socket =
      socket
      |> assign(:filter, "")
      |> reload_assets()

    {:noreply, socket}
  end

  def handle_event("update_all_prices", _params, socket) do
    {:ok, result} = Assets.update_all_asset_data()
    message = Assets.format_update_result_message(result)

    socket =
      socket
      |> assign(:update_result, message)
      |> reload_assets()

    {:noreply, socket}
  end

  def handle_event("show_dividends", %{"id" => id}, socket) do
    asset = Assets.get_asset!(id)
    dividends = Dividends.list_dividends(asset_id: asset.id)

    {:noreply, assign(socket, dividends_modal: %{asset: asset, dividends: dividends})}
  end

  def handle_event("close_dividends_modal", _params, socket) do
    {:noreply, assign(socket, dividends_modal: nil)}
  end

  defp reload_assets(socket) do
    %{user_id: user_id, filter: filter} = socket.assigns
    assets = Assets.list_assets(filter: filter, user_id: user_id)
    stream(socket, :assets, assets, reset: true)
  end

  defp assign_form_error(socket, changeset, asset_params) do
    assign(socket,
      form_errors: changeset,
      asset_in_progress: preserve_asset_input(socket.assigns.asset_in_progress, asset_params)
    )
  end

  defp preserve_asset_input(current, params) do
    %{
      id: current.id,
      name: Map.get(params, "name", current.name),
      price_url: Map.get(params, "price_url", current.price_url),
      currency: Map.get(params, "currency", current.currency),
      distributes_dividends:
        Map.get(params, "distributes_dividends", current.distributes_dividends),
      dividend_url: Map.get(params, "dividend_url", current.dividend_url),
      dividend_withholding_tax:
        Map.get(params, "dividend_withholding_tax", current.dividend_withholding_tax)
    }
  end
end
