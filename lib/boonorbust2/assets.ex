defmodule Boonorbust2.Assets do
  @moduledoc """
  Context module for managing assets.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Repo

  @spec list_assets() :: [Asset.t()]
  def list_assets do
    Helper.do_retry(
      fn ->
        Repo.all(from a in Asset, order_by: a.name)
      end,
      [DBConnection.ConnectionError]
    )
  end

  @spec get_asset!(integer()) :: Asset.t()
  def get_asset!(id), do: Repo.get!(Asset, id)

  @spec get_asset(integer()) :: Asset.t() | nil
  def get_asset(id), do: Repo.get(Asset, id)

  @spec get_asset_by_price_url(String.t()) :: Asset.t() | nil
  def get_asset_by_price_url(price_url), do: Repo.get_by(Asset, price_url: price_url)

  @spec get_asset_by_name(String.t()) :: Asset.t() | nil
  def get_asset_by_name(name), do: Repo.get_by(Asset, name: name)

  @spec create_asset(map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def create_asset(attrs \\ %{}) do
    with {:ok, asset} <- %Asset{} |> Asset.changeset(attrs) |> Repo.insert() do
      maybe_update_price_from_url(asset)
    end
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) do
    # Check if we should update price BEFORE updating the record
    # (because update will change updated_at timestamp)
    should_fetch_price = should_update_price?(asset)

    with {:ok, updated_asset} <- asset |> Asset.changeset(attrs) |> Repo.update() do
      if should_fetch_price do
        fetch_and_update_price(updated_asset)
      else
        {:ok, updated_asset}
      end
    end
  end

  @spec delete_asset(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def delete_asset(%Asset{} = asset) do
    Repo.delete(asset)
  end

  @spec change_asset(Asset.t(), map()) :: Ecto.Changeset.t()
  @spec change_asset(Boonorbust2.Assets.Asset.t()) :: Ecto.Changeset.t()
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end

  @doc """
  Fetches the price from the asset's price_url.

  Returns the first [data][close] value from the JSON response.
  Returns an error if the asset has no price_url or if the request fails.
  """
  @spec fetch_price(Asset.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch_price(%Asset{price_url: nil}), do: {:error, "No price URL configured"}

  def fetch_price(%Asset{price_url: price_url}) do
    access_key = Application.get_env(:boonorbust2, :price_api_access_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(price_url, params: [access_key: access_key]) do
      {:ok, %{status: 200, body: body}} ->
        with %{"data" => [first_data | _]} <- body,
             %{"close" => close_value} <- first_data do
          {:ok, close_value}
        else
          %{"data" => []} -> {:error, "No data available"}
          _ -> {:error, "Invalid response format"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec maybe_update_price_from_url(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp maybe_update_price_from_url(%Asset{} = asset) do
    if should_update_price?(asset) do
      fetch_and_update_price(asset)
    else
      {:ok, asset}
    end
  end

  @spec fetch_and_update_price(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp fetch_and_update_price(%Asset{} = asset) do
    case fetch_price(asset) do
      {:ok, price_value} ->
        asset
        |> Asset.changeset(%{price: price_value})
        |> Repo.update()

      {:error, _reason} ->
        {:ok, asset}
    end
  end

  @spec should_update_price?(Asset.t()) :: boolean()
  defp should_update_price?(%Asset{price_url: nil}), do: false
  defp should_update_price?(%Asset{updated_at: nil}), do: true

  defp should_update_price?(%Asset{inserted_at: inserted_at, updated_at: updated_at}) do
    # Fetch price if this is a new record (inserted_at == updated_at)
    # or if the record is more than 24 hours old
    is_new_record = DateTime.compare(inserted_at, updated_at) == :eq

    if is_new_record do
      true
    else
      now = DateTime.utc_now()
      diff_seconds = DateTime.diff(now, updated_at, :second)
      # 24 hours = 86400 seconds
      diff_seconds >= 86_400
    end
  end
end
