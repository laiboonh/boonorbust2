defmodule Boonorbust2.Assets do
  @moduledoc """
  Context module for managing assets.
  """
  import Ecto.Query, warn: false

  require Logger

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Repo

  @spec list_assets(keyword()) :: [Asset.t()]
  def list_assets(opts \\ []) when is_list(opts) do
    filter = Keyword.get(opts, :filter, nil)
    user_id = Keyword.get(opts, :user_id, nil)
    sort = Keyword.get(opts, :sort, :updated_at)

    Helper.do_retry(
      fn ->
        query =
          case sort do
            :name -> from a in Asset, order_by: [asc: a.name]
            _ -> from a in Asset, order_by: [desc: a.updated_at]
          end

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
  def get_asset!(id) when is_integer(id), do: Repo.get!(Asset, id)

  @spec get_asset(integer()) :: Asset.t() | nil
  def get_asset(id) when is_integer(id), do: Repo.get(Asset, id)

  @spec get_asset_by_price_url(String.t()) :: Asset.t() | nil
  def get_asset_by_price_url(price_url) when is_binary(price_url),
    do: Repo.get_by(Asset, price_url: price_url)

  @spec get_asset_by_name(String.t()) :: Asset.t() | nil
  def get_asset_by_name(name) when is_binary(name), do: Repo.get_by(Asset, name: name)

  @doc """
  Finds an existing asset by name, or creates a new one with the given currency.
  """
  @spec find_or_create_asset(String.t(), String.t()) ::
          {:ok, Asset.t()} | {:error, String.t()}
  def find_or_create_asset(asset_name, currency)
      when is_binary(asset_name) and is_binary(currency) do
    case get_asset_by_name(asset_name) do
      nil -> do_create_asset(asset_name, currency)
      asset -> {:ok, asset}
    end
  end

  @spec do_create_asset(String.t(), String.t()) :: {:ok, Asset.t()} | {:error, String.t()}
  defp do_create_asset(asset_name, currency) do
    attrs = %{name: asset_name, currency: String.upcase(String.trim(currency))}

    case create_asset(attrs) do
      {:ok, asset} ->
        {:ok, asset}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        {:error, inspect(errors)}
    end
  end

  @spec create_asset(map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def create_asset(attrs \\ %{}) do
    Repo.transaction(fn ->
      case %Asset{} |> Asset.changeset(attrs) |> Repo.insert() do
        {:ok, asset} -> fetch_and_sync_on_save(asset)
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) do
    price_url_changed? = url_changed?(attrs, asset.price_url, :price_url)
    dividend_url_changed? = url_changed?(attrs, asset.dividend_url, :dividend_url)

    Repo.transaction(fn ->
      case asset |> Asset.changeset(attrs) |> Repo.update() do
        {:ok, _} ->
          # Reload to get the latest prices_synced_at / dividends_synced_at — these are set
          # by separate Repo.update calls (e.g. during a previous create_asset) and won't
          # be present in the struct returned by this changeset update.
          fresh_asset = Repo.get!(Asset, asset.id)
          should_fetch_price = price_url_changed? or should_update_price?(fresh_asset)
          should_sync_dividends = dividend_url_changed? or should_update_dividends?(fresh_asset)
          fetch_and_sync_on_save(fresh_asset, should_fetch_price, should_sync_dividends)

        {:error, %Ecto.Changeset{} = changeset} ->
          Repo.rollback(changeset)
      end
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

  # Fetches price and syncs dividends after a create or update, inside a transaction.
  # On create, always fetches if URLs are present. On update, respects the should_* flags.
  @spec fetch_and_sync_on_save(Asset.t(), boolean(), boolean()) :: Asset.t()
  defp fetch_and_sync_on_save(asset, should_fetch_price \\ true, should_sync_dividends \\ true) do
    if should_fetch_price and should_sync_dividends and can_use_combined_fetch?(asset) do
      do_combined_save(asset)
    else
      with {:ok, asset} <- maybe_fetch_and_save_price(asset, should_fetch_price),
           {:ok, _} <- maybe_sync_and_save_dividends(asset, should_sync_dividends) do
        asset
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        {:error, reason} when is_binary(reason) -> rollback_with_dividend_error(asset, reason)
      end
    end
  end

  # Single HTTP call for assets where price_url == dividend_url (dividends.sg, etnet).
  # Sets prices_synced_at and dividends_synced_at only when both operations succeed.
  @spec do_combined_save(Asset.t()) :: Asset.t()
  defp do_combined_save(asset) do
    case fetch_combined_data(asset) do
      {:ok, {price, dividends}} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        with {:ok, price_asset} <- fetch_and_save_price_value(asset, price, now),
             {:ok, _} <- Boonorbust2.Dividends.sync_dividends_from_data(price_asset, dividends),
             {:ok, final_asset} <-
               price_asset |> Asset.changeset(%{dividends_synced_at: now}) |> Repo.update() do
          final_asset
        else
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end

      {:error, reason} ->
        rollback_with_price_error(asset, reason)
    end
  end

  @spec can_use_combined_fetch?(Asset.t()) :: boolean()
  defp can_use_combined_fetch?(%Asset{
         price_url: url,
         dividend_url: url,
         distributes_dividends: true
       })
       when not is_nil(url) do
    String.starts_with?(url, "https://www.dividends.sg/") or
      String.starts_with?(url, "https://www.etnet.com.hk/")
  end

  defp can_use_combined_fetch?(_asset), do: false

  @spec maybe_fetch_and_save_price(Asset.t(), boolean()) ::
          {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp maybe_fetch_and_save_price(%Asset{price_url: nil} = asset, _), do: {:ok, asset}
  defp maybe_fetch_and_save_price(asset, false), do: {:ok, asset}

  defp maybe_fetch_and_save_price(asset, true) do
    fetch_and_save_price(asset)
  end

  @spec maybe_sync_and_save_dividends(Asset.t(), boolean()) ::
          {:ok, any()} | {:error, String.t()}
  defp maybe_sync_and_save_dividends(%Asset{dividend_url: nil} = _asset, _), do: {:ok, :skipped}

  defp maybe_sync_and_save_dividends(%Asset{distributes_dividends: false} = _asset, _),
    do: {:ok, :skipped}

  defp maybe_sync_and_save_dividends(_asset, false), do: {:ok, :skipped}

  defp maybe_sync_and_save_dividends(asset, true) do
    sync_and_save_dividends(asset)
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
  """
  @spec fetch_price(Asset.t()) :: {:ok, any()} | {:error, String.t()}
  def fetch_price(%Asset{price_url: nil}), do: {:error, "No price URL configured"}
  def fetch_price(%Asset{price_url: url}), do: Boonorbust2.PriceSources.fetch_price(url)

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

  def fetch_combined_data(%Asset{price_url: url, dividend_url: url}) when is_binary(url),
    do: Boonorbust2.PriceSources.fetch_combined(url)

  def fetch_combined_data(%Asset{}), do: {:error, :unsupported}

  @spec fetch_data(String.t(), (String.t() -> String.t())) :: String.t()
  def fetch_data(response, data_fetcher)
      when is_binary(response) and is_function(data_fetcher, 1) do
    data_fetcher.(response)
  end

  @doc """
  Debug function to inspect the HTML structure of a dividends.sg page.
  Returns various elements that might contain the price.
  """
  def debug_dividends_sg_html(url) do
    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    with {:ok, %{status: 200, body: body}} <- http_client.get(url, []),
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

    with {:ok, %{status: 200, body: body}} <- http_client.get(url, []),
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

  @spec should_update_price?(Asset.t()) :: boolean()
  defp should_update_price?(%Asset{price_url: nil}), do: false
  defp should_update_price?(%Asset{prices_synced_at: nil}), do: true

  defp should_update_price?(%Asset{prices_synced_at: prices_synced_at}) do
    DateTime.diff(DateTime.utc_now(), prices_synced_at, :second) >= 43_200
  end

  @spec should_update_dividends?(Asset.t()) :: boolean()
  defp should_update_dividends?(%Asset{dividend_url: nil}), do: false
  defp should_update_dividends?(%Asset{distributes_dividends: false}), do: false
  defp should_update_dividends?(%Asset{dividends_synced_at: nil}), do: true

  defp should_update_dividends?(%Asset{dividends_synced_at: dividends_synced_at}) do
    DateTime.diff(DateTime.utc_now(), dividends_synced_at, :second) >= 43_200
  end

  # Fetches price from URL, saves price + prices_synced_at. Used in both transaction and
  # scheduled job contexts.
  @spec fetch_and_save_price(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp fetch_and_save_price(asset) do
    case fetch_price(asset) do
      {:ok, price_value} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        asset |> Asset.changeset(%{price: price_value, prices_synced_at: now}) |> Repo.update()

      {:error, reason} ->
        changeset =
          asset
          |> Asset.changeset(%{})
          |> Ecto.Changeset.add_error(:price_url, "Failed to fetch price: #{reason}")

        {:error, changeset}
    end
  end

  # Saves a pre-fetched price value + prices_synced_at in one update.
  # Used inside do_combined_save where the price was already extracted from the HTTP response.
  @spec fetch_and_save_price_value(Asset.t(), any(), DateTime.t()) ::
          {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  defp fetch_and_save_price_value(asset, price_value, now) do
    asset |> Asset.changeset(%{price: price_value, prices_synced_at: now}) |> Repo.update()
  end

  # Syncs dividends from URL and saves dividends_synced_at on success.
  @spec sync_and_save_dividends(Asset.t()) :: {:ok, any()} | {:error, String.t()}
  defp sync_and_save_dividends(asset) do
    with {:ok, result} <- Boonorbust2.Dividends.sync_dividends(asset) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      case asset |> Asset.changeset(%{dividends_synced_at: now}) |> Repo.update() do
        {:ok, _} -> {:ok, result}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @spec format_changeset_errors(Ecto.Changeset.t()) :: String.t()
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  @spec log_timeout_warning(list(Asset.t()), String.t()) :: :ok
  defp log_timeout_warning([], _operation_type), do: :ok

  defp log_timeout_warning(timed_out_assets, operation_type) do
    asset_names = Enum.map_join(timed_out_assets, ", ", & &1.name)

    Logger.warning(
      "#{length(timed_out_assets)} #{operation_type} timed out for assets: #{asset_names}"
    )
  end

  @doc """
  Updates prices and dividends for all assets that have a price_url or dividend_url configured.
  Only updates assets where ANY user currently has holdings (quantity > 0).
  Processes assets in parallel with a maximum concurrency of 5.

  Alpha Vantage-priced assets are the exception: they are processed one at a time
  (never concurrently with each other) to avoid tripping Alpha Vantage's rate limit.
  As soon as one comes back rate-limited, the rest of the Alpha Vantage-priced assets
  for this run are skipped rather than attempted — they'll be picked up on the next run.

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
    Logger.info("Starting update_all_asset_data")

    asset_ids_with_holdings = Boonorbust2.PortfolioPositions.get_asset_ids_with_holdings()
    assets = list_assets()

    assets_with_holdings =
      Enum.filter(assets, fn asset -> asset.id in asset_ids_with_holdings end)

    Logger.info(
      "Found #{length(assets_with_holdings)} assets with holdings out of #{length(assets)} total assets"
    )

    {alpha_vantage_assets, other_assets} =
      Enum.split_with(assets_with_holdings, &alpha_vantage_price_asset?/1)

    other_raw_results =
      other_assets
      |> Task.async_stream(&update_asset_data/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    other_timed_out_assets = extract_timed_out_assets(other_raw_results, other_assets)

    {alpha_vantage_results, alpha_vantage_timed_out_assets} =
      process_alpha_vantage_assets(alpha_vantage_assets)

    log_timeout_warning(
      other_timed_out_assets ++ alpha_vantage_timed_out_assets,
      "update operations"
    )

    other_results =
      Enum.map(other_raw_results, fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, :error}
      end)

    results = other_results ++ alpha_vantage_results

    result = %{
      prices_success: Enum.count(results, fn {p, _} -> p == :fetched end),
      prices_errors: Enum.count(results, fn {p, _} -> p == :error end),
      dividends_success: Enum.count(results, fn {_, d} -> d == :synced end),
      dividends_errors: Enum.count(results, fn {_, d} -> d == :error end)
    }

    Logger.info(
      "Completed update_all_asset_data - " <>
        "Prices: #{result.prices_success} succeeded, #{result.prices_errors} failed. " <>
        "Dividends: #{result.dividends_success} succeeded, #{result.dividends_errors} failed."
    )

    {:ok, result}
  end

  @spec alpha_vantage_price_asset?(Asset.t()) :: boolean()
  defp alpha_vantage_price_asset?(%Asset{price_url: "https://www.alphavantage.co/" <> _}),
    do: true

  defp alpha_vantage_price_asset?(%Asset{}), do: false

  @spec extract_timed_out_assets([{:ok, term()} | {:exit, term()}], [Asset.t()]) :: [Asset.t()]
  defp extract_timed_out_assets(raw_results, assets) do
    raw_results
    |> Enum.zip(assets)
    |> Enum.filter(fn
      {{:exit, :timeout}, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {_, asset} -> asset end)
  end

  @spec rate_limited?(String.t() | nil) :: boolean()
  defp rate_limited?(nil), do: false

  defp rate_limited?(reason) do
    String.contains?(reason, "API limit reached") or String.contains?(reason, "status 429")
  end

  # Processes Alpha Vantage-priced assets one at a time (never concurrently with each
  # other) so a burst of due assets doesn't trip Alpha Vantage's rate limit. As soon as
  # one comes back rate-limited, the rest are skipped for this run instead of being
  # attempted (and burning quota on a request that's very likely to fail too).
  @spec process_alpha_vantage_assets([Asset.t()]) ::
          {[{:fetched | :skipped | :error, :synced | :skipped | :error}], [Asset.t()]}
  defp process_alpha_vantage_assets(assets) do
    {results, timed_out, _rate_limited?} =
      Enum.reduce(assets, {[], [], false}, &process_alpha_vantage_asset/2)

    {Enum.reverse(results), Enum.reverse(timed_out)}
  end

  defp process_alpha_vantage_asset(asset, {results, timed_out, true}) do
    Logger.info(
      "Skipping Alpha Vantage update for asset: #{asset.name} (ID: #{asset.id}) — rate limit hit earlier this run"
    )

    {[{:skipped, :skipped} | results], timed_out, true}
  end

  defp process_alpha_vantage_asset(asset, {results, timed_out, false}) do
    task = Task.async(fn -> update_asset_data_with_price_reason(asset) end)

    case Task.yield(task, 30_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {price_result, div_result, reason}} ->
        if rate_limited?(reason) do
          Logger.warning(
            "Alpha Vantage rate limit hit on asset: #{asset.name} (ID: #{asset.id}) — skipping remaining Alpha Vantage assets for this run"
          )
        end

        {[{price_result, div_result} | results], timed_out, rate_limited?(reason)}

      nil ->
        {[{:error, :error} | results], [asset | timed_out], false}
    end
  end

  # Same as update_asset_data/1 but also surfaces the price fetch failure reason, so
  # the Alpha Vantage circuit breaker can detect a rate limit without re-fetching.
  @spec update_asset_data_with_price_reason(Asset.t()) ::
          {:fetched | :skipped | :error, :synced | :skipped | :error, String.t() | nil}
  defp update_asset_data_with_price_reason(asset) do
    needs_price? = should_update_price?(asset)
    needs_dividends? = should_update_dividends?(asset)

    {price_result, reason} =
      if needs_price?, do: run_price_update_with_reason(asset), else: {:skipped, nil}

    div_result = if needs_dividends?, do: run_dividend_sync(asset), else: :skipped

    {price_result, div_result, reason}
  end

  # Per-asset update function run by the scheduled job.
  # Returns {price_result, dividend_result} where each is :fetched/:synced/:skipped/:error.
  # Uses a single HTTP call when both are due and the URL supports combined fetch.
  @spec update_asset_data(Asset.t()) ::
          {:fetched | :skipped | :error, :synced | :skipped | :error}
  defp update_asset_data(asset) do
    needs_price? = should_update_price?(asset)
    needs_dividends? = should_update_dividends?(asset)

    if needs_price? and needs_dividends? and can_use_combined_fetch?(asset) do
      case fetch_and_save_combined(asset) do
        {:ok, _} ->
          Logger.info(
            "Successfully updated price and dividends for asset: #{asset.name} (ID: #{asset.id})"
          )

          {:fetched, :synced}

        {:error, reason} ->
          Logger.error(
            "Failed combined update for asset: #{asset.name} (ID: #{asset.id}). Reason: #{inspect(reason)}"
          )

          {:error, :error}
      end
    else
      price_result = if needs_price?, do: run_price_update(asset), else: :skipped
      div_result = if needs_dividends?, do: run_dividend_sync(asset), else: :skipped
      {price_result, div_result}
    end
  end

  @spec run_price_update(Asset.t()) :: :fetched | :error
  defp run_price_update(asset) do
    {result, _reason} = run_price_update_with_reason(asset)
    result
  end

  # Same as run_price_update/1 but also surfaces the raw failure reason, so callers
  # can detect specific failure causes (e.g. an upstream API rate limit) without
  # re-fetching. Used by the Alpha Vantage circuit breaker in process_alpha_vantage_asset/2.
  @spec run_price_update_with_reason(Asset.t()) :: {:fetched | :error, String.t() | nil}
  defp run_price_update_with_reason(asset) do
    case fetch_price(asset) do
      {:ok, price_value} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        case fetch_and_save_price_value(asset, price_value, now) do
          {:ok, _} ->
            Logger.info("Successfully fetched price for asset: #{asset.name} (ID: #{asset.id})")
            {:fetched, nil}

          {:error, changeset} ->
            Logger.error(
              "Failed to fetch price for asset: #{asset.name} (ID: #{asset.id}). Errors: #{format_changeset_errors(changeset)}"
            )

            {:error, nil}
        end

      {:error, reason} ->
        Logger.error(
          "Failed to fetch price for asset: #{asset.name} (ID: #{asset.id}). Reason: #{reason}"
        )

        {:error, reason}
    end
  end

  @spec run_dividend_sync(Asset.t()) :: :synced | :error
  defp run_dividend_sync(asset) do
    case sync_and_save_dividends(asset) do
      {:ok, _} ->
        Logger.info("Successfully synced dividends for asset: #{asset.name} (ID: #{asset.id})")
        :synced

      {:error, reason} ->
        Logger.error(
          "Failed to sync dividends for asset: #{asset.name} (ID: #{asset.id}). Reason: #{inspect(reason)}"
        )

        :error
    end
  end

  # Combined fetch for the scheduled job (not inside a transaction).
  # Sets prices_synced_at immediately, dividends_synced_at after both succeed.
  @spec fetch_and_save_combined(Asset.t()) :: {:ok, Asset.t()} | {:error, any()}
  defp fetch_and_save_combined(asset) do
    case fetch_combined_data(asset) do
      {:ok, {price, dividends}} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        with {:ok, price_asset} <- fetch_and_save_price_value(asset, price, now),
             {:ok, _} <- Boonorbust2.Dividends.sync_dividends_from_data(price_asset, dividends) do
          price_asset |> Asset.changeset(%{dividends_synced_at: now}) |> Repo.update()
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Formats the result message for update_all_asset_data operation.

  Returns a user-friendly message describing the success/failure of price and dividend updates.
  """
  @spec format_update_result_message(%{
          prices_success: non_neg_integer(),
          prices_errors: non_neg_integer(),
          dividends_success: non_neg_integer(),
          dividends_errors: non_neg_integer()
        }) :: String.t()
  def format_update_result_message(%{
        prices_success: prices_success,
        prices_errors: prices_errors,
        dividends_success: dividends_success,
        dividends_errors: dividends_errors
      }) do
    total_errors = prices_errors + dividends_errors

    if total_errors > 0 do
      "Updated #{prices_success} prices, #{dividends_success} dividends (#{total_errors} errors)"
    else
      "Successfully updated #{prices_success} prices and #{dividends_success} dividends"
    end
  end
end
