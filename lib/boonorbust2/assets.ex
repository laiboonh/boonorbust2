defmodule Boonorbust2.Assets do
  @moduledoc """
  Context module for managing assets.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Repo

  @spec list_assets(keyword()) :: [Asset.t()]
  def list_assets(opts \\ []) do
    filter = Keyword.get(opts, :filter, nil)

    Helper.do_retry(
      fn ->
        query = from a in Asset, order_by: a.name
        query = apply_filter(query, filter)
        Repo.all(query)
      end,
      [DBConnection.ConnectionError]
    )
  end

  @spec apply_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_filter(query, nil), do: query
  defp apply_filter(query, ""), do: query

  defp apply_filter(query, filter) when is_binary(filter) do
    filter_pattern = "%#{filter}%"

    from a in query,
      where: ilike(a.name, ^filter_pattern)
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
    Repo.transaction(fn ->
      with {:ok, asset} <- %Asset{} |> Asset.changeset(attrs) |> Repo.insert(),
           {:ok, updated_asset} <- maybe_update_price_from_url(asset) do
        updated_asset
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) do
    # Check if price_url value has actually changed
    new_price_url = Map.get(attrs, :price_url) || Map.get(attrs, "price_url")
    current_price_url = asset.price_url

    price_url_changed? =
      case new_price_url do
        nil -> false
        ^current_price_url -> false
        _ -> true
      end

    # Check if we should update price BEFORE updating the record
    # (because update will change updated_at timestamp)
    should_fetch_price = price_url_changed? or should_update_price?(asset)

    Repo.transaction(fn ->
      do_update_asset(asset, attrs, should_fetch_price)
    end)
  end

  @spec do_update_asset(Asset.t(), map(), boolean()) :: Asset.t()
  defp do_update_asset(asset, attrs, should_fetch_price) do
    with {:ok, updated_asset} <- asset |> Asset.changeset(attrs) |> Repo.update(),
         {:ok, final_asset} <- maybe_fetch_price(updated_asset, should_fetch_price) do
      final_asset
    else
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @spec maybe_fetch_price(Asset.t(), boolean()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp maybe_fetch_price(asset, true) when not is_nil(asset.price_url) do
    fetch_and_update_price(asset)
  end

  defp maybe_fetch_price(asset, _), do: {:ok, asset}

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

  def fetch_price(%Asset{price_url: "https://api.marketstack.com" <> _rest = price_url}) do
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

  def fetch_price(%Asset{price_url: "https://www.dollardex.com/" <> _rest = price_url}) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(price_url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, document} = Floki.parse_document(body)

        result =
          Floki.find(document, "#grid1 > div > div.price.clear")
          |> Floki.text()
          |> String.split("\n")
          |> hd()

        {:ok, result}

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_price(%Asset{price_url: "https://markets.ft.com/" <> _rest = price_url}) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(price_url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, document} = Floki.parse_document(body)

        result =
          Floki.find(
            document,
            "body > div.o-grid-container.mod-container > div:nth-child(2) > section:nth-child(1) > div > div > div.mod-tearsheet-overview__overview.clearfix > div.mod-tearsheet-overview__quote > ul > li:nth-child(1) > span.mod-ui-data-list__value"
          )
          |> Floki.text()
          |> String.split("\n")
          |> hd()

        {:ok, result}

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_price(%Asset{price_url: price_url}) do
    {:error, "Request failed: Unexpected price url #{price_url}"}
  end

  @spec fetch_data(String.t(), (String.t() -> String.t())) :: String.t()
  def fetch_data(response, data_fetcher) do
    data_fetcher.(response)
  end

  @spec maybe_update_price_from_url(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp maybe_update_price_from_url(%Asset{price_url: nil} = asset), do: {:ok, asset}

  defp maybe_update_price_from_url(%Asset{} = asset) do
    # For CREATE, always fetch the price if price_url is set
    fetch_and_update_price(asset)
  end

  @spec fetch_and_update_price(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp fetch_and_update_price(%Asset{} = asset) do
    case fetch_price(asset) do
      {:ok, price_value} ->
        # Force updated_at to be set even if price hasn't changed
        # This ensures rate limiting works correctly
        asset
        |> Asset.changeset(%{price: price_value})
        |> Ecto.Changeset.force_change(
          :updated_at,
          DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()

      {:error, reason} ->
        changeset =
          asset
          |> Asset.changeset(%{})
          |> Ecto.Changeset.add_error(:price_url, "Failed to fetch price: #{reason}")

        {:error, changeset}
    end
  end

  @spec should_update_price?(Asset.t()) :: boolean()
  defp should_update_price?(%Asset{price_url: nil}), do: false
  defp should_update_price?(%Asset{updated_at: nil}), do: true

  defp should_update_price?(%Asset{updated_at: updated_at}) do
    # Fetch price if the record is more than 24 hours old
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, updated_at, :second)
    # 24 hours = 86400 seconds
    diff_seconds >= 86_400
  end

  @spec fetch_asset_price(Asset.t()) :: :fetched | :skipped | :error
  defp fetch_asset_price(asset) do
    should_fetch = should_update_price?(asset)

    case maybe_fetch_price(asset, should_fetch) do
      {:ok, _updated_asset} -> if should_fetch, do: :fetched, else: :skipped
      {:error, _changeset} -> :error
    end
  end

  @doc """
  Updates prices for all assets that have a price_url configured.
  Only updates assets where ANY user currently has holdings (quantity > 0).
  Processes assets in parallel with a maximum concurrency of 5.

  Returns a tuple with success count (actually fetched) and error count.
  Assets skipped due to rate limiting are not counted as successes.
  """
  @spec update_all_prices() :: {:ok, %{success: non_neg_integer(), errors: non_neg_integer()}}
  def update_all_prices do
    # Get asset IDs where ANY user has holdings (quantity > 0)
    asset_ids_with_holdings = Boonorbust2.PortfolioPositions.get_asset_ids_with_holdings()

    assets = list_assets()

    # Filter to only assets with price_url AND where any user has holdings
    assets_with_price_url =
      Enum.filter(assets, fn asset ->
        not is_nil(asset.price_url) and asset.id in asset_ids_with_holdings
      end)

    results =
      assets_with_price_url
      |> Task.async_stream(
        &fetch_asset_price/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    success_count =
      Enum.count(results, fn {status, result} -> status == :ok and result == :fetched end)

    error_count =
      Enum.count(results, fn {status, result} -> status == :ok and result == :error end)

    {:ok, %{success: success_count, errors: error_count}}
  end
end
