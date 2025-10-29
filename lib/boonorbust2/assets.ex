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
    user_id = Keyword.get(opts, :user_id, nil)

    Helper.do_retry(
      fn ->
        query = from a in Asset, order_by: a.name
        query = apply_filter(query, filter, user_id)
        Repo.all(query)
      end,
      [DBConnection.ConnectionError]
    )
  end

  @spec apply_filter(Ecto.Query.t(), String.t() | nil, String.t() | nil) :: Ecto.Query.t()
  defp apply_filter(query, nil, _user_id), do: query
  defp apply_filter(query, "", _user_id), do: query

  defp apply_filter(query, filter, user_id) when is_binary(filter) and not is_nil(user_id) do
    # First check if the filter matches a tag name
    case Boonorbust2.Tags.get_tag_by_name(filter, user_id) do
      nil ->
        # Not a tag, filter by asset name
        apply_asset_name_filter(query, filter)

      tag ->
        # It's a tag, get all asset IDs for this tag
        asset_ids = Boonorbust2.Tags.list_assets_for_tag(tag.id)

        if Enum.empty?(asset_ids) do
          # No assets with this tag, return empty result
          from a in query, where: false
        else
          from a in query,
            where: a.id in ^asset_ids
        end
    end
  end

  defp apply_filter(query, filter, nil) when is_binary(filter) do
    # No user_id provided, can only filter by asset name
    apply_asset_name_filter(query, filter)
  end

  @spec apply_asset_name_filter(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp apply_asset_name_filter(query, filter) do
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
      case %Asset{} |> Asset.changeset(attrs) |> Repo.insert() do
        {:ok, asset} -> handle_asset_creation(asset)
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec handle_asset_creation(Asset.t()) :: Asset.t()
  defp handle_asset_creation(asset) do
    if can_use_combined_fetch?(asset) do
      do_combined_create(asset)
    else
      do_separate_creates(asset)
    end
  end

  @spec do_combined_create(Asset.t()) :: Asset.t()
  defp do_combined_create(asset) do
    case fetch_combined_data(asset) do
      {:ok, {price, dividends}} ->
        with {:ok, price_updated_asset} <- update_asset_price(asset, price),
             {:ok, final_asset} <- sync_dividends_from_data(price_updated_asset, dividends) do
          final_asset
        else
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end

      {:error, reason} ->
        rollback_with_price_error(asset, reason)
    end
  end

  @spec do_separate_creates(Asset.t()) :: Asset.t()
  defp do_separate_creates(asset) do
    with {:ok, updated_asset} <- maybe_update_price_from_url(asset),
         :ok <- maybe_sync_dividends_from_url(updated_asset) do
      updated_asset
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback(changeset)

      {:error, reason} when is_binary(reason) ->
        rollback_with_dividend_error(asset, reason)
    end
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) do
    price_url_changed? = url_changed?(attrs, asset.price_url, :price_url)
    dividend_url_changed? = url_changed?(attrs, asset.dividend_url, :dividend_url)

    # Check if we should update price/dividends BEFORE updating the record
    # (because update will change updated_at timestamp)
    should_fetch_price = price_url_changed? or should_update_price?(asset)
    should_sync_dividends = dividend_url_changed? or should_update_dividends?(asset)

    Repo.transaction(fn ->
      do_update_asset(asset, attrs, should_fetch_price, should_sync_dividends)
    end)
  end

  @spec url_changed?(map(), String.t() | nil, atom()) :: boolean()
  defp url_changed?(attrs, current_url, field) do
    new_url = Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))

    case new_url do
      nil -> false
      ^current_url -> false
      _ -> true
    end
  end

  @spec do_update_asset(Asset.t(), map(), boolean(), boolean()) :: Asset.t()
  defp do_update_asset(asset, attrs, should_fetch_price, should_sync_dividends) do
    case asset |> Asset.changeset(attrs) |> Repo.update() do
      {:ok, updated_asset} ->
        handle_asset_update(updated_asset, should_fetch_price, should_sync_dividends)

      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback(changeset)
    end
  end

  @spec handle_asset_update(Asset.t(), boolean(), boolean()) :: Asset.t()
  defp handle_asset_update(asset, should_fetch_price, should_sync_dividends) do
    # Try combined fetch if both price and dividends need updating and URLs match
    if should_fetch_price and should_sync_dividends and can_use_combined_fetch?(asset) do
      do_combined_update(asset)
    else
      # Fall back to separate fetches
      do_separate_updates(asset, should_fetch_price, should_sync_dividends)
    end
  end

  @spec can_use_combined_fetch?(Asset.t()) :: boolean()
  defp can_use_combined_fetch?(%Asset{
         price_url: url,
         dividend_url: url,
         distributes_dividends: true
       })
       when not is_nil(url) do
    # Check if URL is supported for combined fetch
    case url do
      "https://www.dividends.sg/" <> _ -> true
      "https://www.etnet.com.hk/" <> _ -> true
      _ -> false
    end
  end

  defp can_use_combined_fetch?(_asset), do: false

  @spec do_combined_update(Asset.t()) :: Asset.t()
  defp do_combined_update(asset) do
    case fetch_combined_data(asset) do
      {:ok, {price, dividends}} ->
        # Update both price and dividends from the single fetch
        with {:ok, price_updated_asset} <- update_asset_price(asset, price),
             {:ok, final_asset} <- sync_dividends_from_data(price_updated_asset, dividends) do
          final_asset
        else
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end

      {:error, reason} ->
        # Combined fetch failed, rollback with error
        rollback_with_price_error(asset, reason)
    end
  end

  @spec do_separate_updates(Asset.t(), boolean(), boolean()) :: Asset.t()
  defp do_separate_updates(asset, should_fetch_price, should_sync_dividends) do
    with {:ok, price_updated_asset} <- maybe_fetch_price(asset, should_fetch_price),
         {:ok, final_asset} <- maybe_sync_dividends(price_updated_asset, should_sync_dividends) do
      final_asset
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback(changeset)

      {:error, reason} when is_binary(reason) ->
        rollback_with_dividend_error(asset, reason)
    end
  end

  @spec update_asset_price(Asset.t(), any()) ::
          {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp update_asset_price(asset, price_value) do
    asset
    |> Asset.changeset(%{price: price_value})
    |> Ecto.Changeset.force_change(:updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @spec sync_dividends_from_data(Asset.t(), [map()]) :: {:ok, Asset.t()}
  defp sync_dividends_from_data(asset, dividends) do
    {:ok, _result} = Boonorbust2.Dividends.sync_dividends_from_data(asset, dividends)

    # Force updated_at to be set
    asset
    |> Asset.changeset(%{})
    |> Ecto.Changeset.force_change(
      :updated_at,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update()
  end

  @spec rollback_with_dividend_error(Asset.t(), String.t()) :: no_return()
  defp rollback_with_dividend_error(asset, reason) do
    changeset =
      asset
      |> Asset.changeset(%{})
      |> Ecto.Changeset.add_error(:dividend_url, "Failed to sync dividends: #{reason}")

    Repo.rollback(changeset)
  end

  @spec rollback_with_price_error(Asset.t(), String.t()) :: no_return()
  defp rollback_with_price_error(asset, reason) do
    changeset =
      asset
      |> Asset.changeset(%{})
      |> Ecto.Changeset.add_error(:price_url, "Failed to fetch price: #{reason}")

    Repo.rollback(changeset)
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

  def fetch_price(%Asset{price_url: "https://www.alphavantage.co/" <> _rest = price_url}) do
    access_key = Application.get_env(:boonorbust2, :alphavantage_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(price_url, params: [apikey: access_key]) do
      {:ok, %{status: 200, body: body}} ->
        with %{"Time Series (Daily)" => time_series} <- body,
             # Get the most recent date (first key in the map)
             [first_date | _] <- Map.keys(time_series) |> Enum.sort(:desc),
             %{"4. close" => close_value} <- time_series[first_date] do
          {:ok, close_value}
        else
          %{"Time Series (Daily)" => _} -> {:error, "No data available"}
          %{"Error Message" => error_msg} -> {:error, "API error: #{error_msg}"}
          %{"Note" => note} -> {:error, "API limit reached: #{note}"}
          _ -> {:error, "Invalid response format"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_price(%Asset{price_url: "https://v6.exchangerate-api.com/" <> _rest = price_url}) do
    api_key = Application.get_env(:boonorbust2, :exchange_rate_api_key)

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(price_url, auth: {:bearer, api_key}) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"conversion_rate" => rate} ->
            {:ok, rate}

          _ ->
            {:error, "Invalid response format"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  def fetch_price(%Asset{price_url: "https://www.etnet.com.hk/" <> _rest = price_url}) do
    # Scrape price from etnet.com.hk website
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(price_url),
         {:ok, document} <- Floki.parse_document(body),
         {:ok, price} <- parse_etnet_price(document) do
      {:ok, price}
    else
      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, :price_not_found} ->
        {:error, "Price not found on page"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  def fetch_price(%Asset{price_url: "https://www.dividends.sg/" <> _rest = price_url}) do
    # Scrape price from dividends.sg website
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(price_url),
         {:ok, document} <- Floki.parse_document(body),
         {:ok, price} <- parse_dividends_sg_price(document) do
      {:ok, price}
    else
      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, :price_not_found} ->
        {:error, "Price not found on page"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  def fetch_price(%Asset{price_url: price_url}) do
    {:error, "Request failed: Unexpected price url #{price_url}"}
  end

  @spec parse_etnet_price(Floki.html_tree()) :: {:ok, String.t()} | {:error, :price_not_found}
  defp parse_etnet_price(document) do
    # Find span with class HeaderTxt (can be "HeaderTxt up" or "HeaderTxt down")
    result =
      document
      |> Floki.find("span")
      |> Enum.find_value(fn element ->
        extract_header_txt_price(element)
      end)

    case result do
      nil -> {:error, :price_not_found}
      price -> {:ok, price}
    end
  end

  @spec extract_header_txt_price(Floki.html_node()) :: String.t() | nil
  defp extract_header_txt_price({_tag, attrs, [text | _]}) when is_binary(text) do
    with {"class", class_value} <- List.keyfind(attrs, "class", 0),
         true <- String.contains?(class_value, "HeaderTxt") do
      String.trim(text)
    else
      _ -> nil
    end
  end

  defp extract_header_txt_price(_), do: nil

  @spec parse_dividends_sg_price(Floki.html_tree()) ::
          {:ok, String.t()} | {:error, :price_not_found}
  defp parse_dividends_sg_price(document) do
    # Try multiple selectors to find the price
    result =
      [".col-md-8 h4 span", "h4 span", "div.col-md-8 > h4 > span"]
      |> Enum.find_value(&extract_price_from_selector(document, &1))

    case result do
      nil -> {:error, :price_not_found}
      price -> {:ok, price}
    end
  end

  @spec extract_price_from_selector(Floki.html_tree(), String.t()) :: String.t() | nil
  defp extract_price_from_selector(document, selector) do
    document
    |> Floki.find(selector)
    |> case do
      [] -> nil
      elements -> extract_numeric_price(elements)
    end
  end

  @spec extract_numeric_price(list()) :: String.t() | nil
  defp extract_numeric_price(elements) do
    text = Floki.text(elements) |> String.trim()

    # Extract just the numeric part (e.g., "6.37" from "USD 6.37" or "1" from "SGD 1")
    # Matches integers (e.g., "1") or decimals (e.g., "1.23")
    case Regex.run(~r/\d+(?:\.\d+)?/, text) do
      [price] -> price
      _ -> nil
    end
  end

  @doc """
  Fetches both price and dividends from a single URL when price_url == dividend_url.
  This optimization reduces HTTP calls when an asset uses the same URL for both data sources.

  Returns {:ok, {price, dividends}} or {:error, reason}.
  Only works for URLs that support both price and dividend data.
  """
  @spec fetch_combined_data(Asset.t()) ::
          {:ok, {any(), [map()]}} | {:error, String.t()} | {:error, :unsupported}
  def fetch_combined_data(%Asset{price_url: nil}), do: {:error, "No price URL configured"}
  def fetch_combined_data(%Asset{dividend_url: nil}), do: {:error, "No dividend URL configured"}

  def fetch_combined_data(%Asset{price_url: url, dividend_url: url} = asset)
      when is_binary(url) do
    # URLs match - we can fetch both from the same response
    case url do
      "https://www.dividends.sg/" <> _rest -> fetch_combined_dividends_sg(asset, url)
      "https://www.etnet.com.hk/" <> _rest -> fetch_combined_etnet(asset, url)
      _ -> {:error, :unsupported}
    end
  end

  def fetch_combined_data(%Asset{}), do: {:error, :unsupported}

  @spec fetch_combined_dividends_sg(Asset.t(), String.t()) ::
          {:ok, {String.t(), [map()]}} | {:error, String.t()}
  defp fetch_combined_dividends_sg(_asset, url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, document} <- Floki.parse_document(body),
             {:ok, price} <- parse_dividends_sg_price(document),
             {:ok, dividends} <- Boonorbust2.Dividends.parse_dividends_sg_document(document) do
          {:ok, {price, dividends}}
        else
          {:error, :price_not_found} -> {:error, "Price not found on page"}
          {:error, reason} -> {:error, reason}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec fetch_combined_etnet(Asset.t(), String.t()) ::
          {:ok, {String.t(), [map()]}} | {:error, String.t()}
  defp fetch_combined_etnet(_asset, url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(url) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, document} <- Floki.parse_document(body),
             {:ok, price} <- parse_etnet_price(document),
             {:ok, dividends} <- Boonorbust2.Dividends.parse_etnet_document(document) do
          {:ok, {price, dividends}}
        else
          {:error, :price_not_found} -> {:error, "Price not found on page"}
          {:error, reason} -> {:error, reason}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec fetch_data(String.t(), (String.t() -> String.t())) :: String.t()
  def fetch_data(response, data_fetcher) do
    data_fetcher.(response)
  end

  @doc """
  Debug function to inspect the HTML structure of a dividends.sg page.
  Returns various elements that might contain the price.
  """
  def debug_dividends_sg_html(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(url),
         {:ok, document} <- Floki.parse_document(body) do
      {:ok,
       %{
         h4_elements: extract_h4_elements(document),
         numeric_elements: extract_numeric_elements(document),
         all_spans: extract_all_spans(document)
       }}
    else
      {:error, error} -> {:error, error}
      {:ok, %{status: _status}} -> {:error, "HTTP request failed"}
    end
  end

  @doc """
  Debug function to inspect the HTML structure of an etnet.com.hk page.
  Returns a list of all elements with class attributes containing "price" (case-insensitive).
  """
  def debug_etnet_html(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(url),
         {:ok, document} <- Floki.parse_document(body) do
      {:ok,
       %{
         relevant_ids: extract_relevant_ids(document),
         numeric_elements: extract_numeric_elements(document),
         scripts_with_price: extract_price_scripts(document)
       }}
    else
      {:error, error} -> {:error, error}
      {:ok, %{status: _status}} -> {:error, "HTTP request failed"}
    end
  end

  defp extract_relevant_ids(document) do
    document
    |> Floki.find("[id]")
    |> Enum.filter(&has_relevant_id?/1)
    |> Enum.map(fn {tag, attrs, children} ->
      id = List.keyfind(attrs, "id", 0)
      text = Floki.text({tag, attrs, children}) |> String.trim() |> String.slice(0..100)
      {tag, id, text}
    end)
  end

  defp has_relevant_id?({_tag, attrs, _children}) do
    case List.keyfind(attrs, "id", 0) do
      {"id", id_value} ->
        id_lower = String.downcase(id_value)

        String.contains?(id_lower, "stock") or
          String.contains?(id_lower, "detail") or
          String.contains?(id_lower, "main") or
          String.contains?(id_lower, "price")

      _ ->
        false
    end
  end

  defp extract_numeric_elements(document) do
    document
    |> Floki.find("span, div")
    |> Enum.filter(fn element ->
      text = Floki.text(element) |> String.trim()
      String.match?(text, ~r/^\d+\.\d{2,3}$/)
    end)
    |> Enum.map(fn {tag, attrs, children} ->
      id = List.keyfind(attrs, "id", 0)
      class = List.keyfind(attrs, "class", 0)
      text = Floki.text({tag, attrs, children}) |> String.trim()
      {tag, id, class, text}
    end)
    |> Enum.take(10)
  end

  defp extract_price_scripts(document) do
    document
    |> Floki.find("script")
    |> Enum.map(fn element ->
      Floki.text(element) |> String.slice(0..200)
    end)
    |> Enum.filter(fn text ->
      String.contains?(text, "price") or String.contains?(text, "Price")
    end)
    |> Enum.take(3)
  end

  defp extract_h4_elements(document) do
    document
    |> Floki.find("h4")
    |> Enum.map(fn {tag, attrs, children} ->
      class = List.keyfind(attrs, "class", 0)
      text = Floki.text({tag, attrs, children}) |> String.trim() |> String.slice(0..200)
      {tag, class, text, inspect(children) |> String.slice(0..300)}
    end)
  end

  defp extract_all_spans(document) do
    document
    |> Floki.find("span")
    |> Enum.map(fn {tag, attrs, children} ->
      class = List.keyfind(attrs, "class", 0)
      text = Floki.text({tag, attrs, children}) |> String.trim()
      {class, text}
    end)
    |> Enum.filter(fn {_class, text} ->
      # Filter to spans that contain numbers
      String.match?(text, ~r/\d/)
    end)
    |> Enum.take(20)
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

  @spec should_update_dividends?(Asset.t()) :: boolean()
  defp should_update_dividends?(%Asset{dividend_url: nil}), do: false
  defp should_update_dividends?(%Asset{distributes_dividends: false}), do: false
  defp should_update_dividends?(%Asset{updated_at: nil}), do: true

  defp should_update_dividends?(%Asset{updated_at: updated_at}) do
    # Sync dividends if the record is more than 24 hours old
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, updated_at, :second)
    # 24 hours = 86400 seconds
    diff_seconds >= 86_400
  end

  @spec maybe_sync_dividends_from_url(Asset.t()) :: :ok | {:error, String.t()}
  defp maybe_sync_dividends_from_url(%Asset{dividend_url: nil} = _asset), do: :ok
  defp maybe_sync_dividends_from_url(%Asset{distributes_dividends: false} = _asset), do: :ok

  defp maybe_sync_dividends_from_url(%Asset{} = asset) do
    # For CREATE, always sync dividends if dividend_url is set and distributes_dividends is true
    case sync_asset_dividends(asset) do
      {:ok, _updated_asset} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec maybe_sync_dividends(Asset.t(), boolean()) :: {:ok, Asset.t()} | {:error, String.t()}
  defp maybe_sync_dividends(asset, false), do: {:ok, asset}
  defp maybe_sync_dividends(%Asset{dividend_url: nil} = asset, true), do: {:ok, asset}
  defp maybe_sync_dividends(%Asset{distributes_dividends: false} = asset, true), do: {:ok, asset}

  defp maybe_sync_dividends(%Asset{} = asset, true) do
    sync_asset_dividends(asset)
  end

  @spec sync_asset_dividends(Asset.t()) :: {:ok, Asset.t()} | {:error, String.t()}
  defp sync_asset_dividends(%Asset{} = asset) do
    case Boonorbust2.Dividends.sync_dividends(asset) do
      {:ok, _result} ->
        # Force updated_at to be set even if no asset fields changed
        # This ensures rate limiting works correctly for dividend syncing
        asset
        |> Asset.changeset(%{})
        |> Ecto.Changeset.force_change(
          :updated_at,
          DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_asset_price(Asset.t()) :: :fetched | :skipped | :error
  defp fetch_asset_price(asset) do
    should_fetch = should_update_price?(asset)

    case maybe_fetch_price(asset, should_fetch) do
      {:ok, _updated_asset} -> if should_fetch, do: :fetched, else: :skipped
      {:error, _changeset} -> :error
    end
  end

  @spec sync_asset_dividends_with_status(Asset.t()) :: :synced | :skipped | :error
  defp sync_asset_dividends_with_status(asset) do
    should_sync = should_update_dividends?(asset)

    case maybe_sync_dividends(asset, should_sync) do
      {:ok, _updated_asset} -> if should_sync, do: :synced, else: :skipped
      {:error, _reason} -> :error
    end
  end

  @doc """
  Updates prices and dividends for all assets that have a price_url or dividend_url configured.
  Only updates assets where ANY user currently has holdings (quantity > 0).
  Processes assets in parallel with a maximum concurrency of 5.

  Optimizes by making a single HTTP call when price_url == dividend_url.

  Returns a tuple with counts for prices and dividends (actually fetched/synced).
  Assets skipped due to rate limiting are not counted as successes.
  """
  @spec update_all_asset_data() ::
          {:ok,
           %{
             prices_success: non_neg_integer(),
             prices_errors: non_neg_integer(),
             dividends_success: non_neg_integer(),
             dividends_errors: non_neg_integer()
           }}
  def update_all_asset_data do
    # Get asset IDs where ANY user has holdings (quantity > 0)
    asset_ids_with_holdings = Boonorbust2.PortfolioPositions.get_asset_ids_with_holdings()

    assets = list_assets()

    # Filter to assets where any user has holdings
    assets_with_holdings =
      Enum.filter(assets, fn asset ->
        asset.id in asset_ids_with_holdings
      end)

    # Separate assets into those that can use combined fetch and those that can't
    {assets_for_combined, assets_for_separate} =
      Enum.split_with(assets_with_holdings, fn asset ->
        should_update_price?(asset) and should_update_dividends?(asset) and
          can_use_combined_fetch?(asset)
      end)

    # Process combined fetch assets (single HTTP call per asset)
    combined_results =
      assets_for_combined
      |> Task.async_stream(
        &fetch_and_update_combined/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    combined_prices_success =
      Enum.count(combined_results, fn
        {:ok, {:fetched, :synced}} -> true
        _ -> false
      end)

    combined_prices_errors =
      Enum.count(combined_results, fn
        {:ok, {:error, _}} -> true
        _ -> false
      end)

    combined_dividends_success = combined_prices_success
    combined_dividends_errors = combined_prices_errors

    # Process remaining assets separately
    # Update prices for assets with price_url (excluding those already processed)
    assets_with_price_url =
      Enum.filter(assets_for_separate, fn asset -> not is_nil(asset.price_url) end)

    price_results =
      assets_with_price_url
      |> Task.async_stream(
        &fetch_asset_price/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    prices_success =
      Enum.count(price_results, fn {status, result} -> status == :ok and result == :fetched end)

    prices_errors =
      Enum.count(price_results, fn {status, result} -> status == :ok and result == :error end)

    # Update dividends for assets with dividend_url and distributes_dividends = true
    # (excluding those already processed)
    assets_with_dividend_url =
      Enum.filter(assets_for_separate, fn asset ->
        not is_nil(asset.dividend_url) and asset.distributes_dividends
      end)

    dividend_results =
      assets_with_dividend_url
      |> Task.async_stream(
        &sync_asset_dividends_with_status/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    dividends_success =
      Enum.count(dividend_results, fn {status, result} -> status == :ok and result == :synced end)

    dividends_errors =
      Enum.count(dividend_results, fn {status, result} -> status == :ok and result == :error end)

    {:ok,
     %{
       prices_success: prices_success + combined_prices_success,
       prices_errors: prices_errors + combined_prices_errors,
       dividends_success: dividends_success + combined_dividends_success,
       dividends_errors: dividends_errors + combined_dividends_errors
     }}
  end

  @spec fetch_and_update_combined(Asset.t()) ::
          {:fetched, :synced} | {:error, String.t()}
  defp fetch_and_update_combined(asset) do
    case fetch_combined_data(asset) do
      {:ok, {price, dividends}} ->
        with {:ok, _price_asset} <- update_asset_price(asset, price),
             {:ok, _div_result} <- sync_dividends_from_data(asset, dividends) do
          {:fetched, :synced}
        else
          {:error, _} -> {:error, "Failed to update asset"}
        end

      {:error, _reason} ->
        {:error, "Failed to fetch combined data"}
    end
  end
end
