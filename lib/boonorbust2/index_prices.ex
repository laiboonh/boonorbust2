defmodule Boonorbust2.IndexPrices do
  @moduledoc """
  Fetches and caches the latest price for an index/ETF ticker from Yahoo Finance's
  chart API. Mirrors `Boonorbust2.ExchangeRates`'s Cachex TTL pattern: today's close
  isn't immutable (market may still be open), so it is cached with a 1-hour TTL
  rather than persisted.
  """

  require Logger

  @cache_name :index_prices_cache
  # Cache for 1 hour (in milliseconds)
  @cache_ttl :timer.hours(1)
  # Trailing window in days to absorb weekends/holidays with no trading activity
  @window_days 10

  @doc """
  Gets the latest known closing price for the given ticker. Returns cached data if
  available, otherwise fetches from Yahoo Finance's chart API and caches the result.

  Returns `{:ok, price}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Boonorbust2.IndexPrices.get_latest_price("VWRA.L")
      {:ok, 145.32}

  """
  @spec get_latest_price(String.t()) :: {:ok, float()} | {:error, term()}
  def get_latest_price(ticker) when is_binary(ticker) do
    case Cachex.get(@cache_name, ticker) do
      {:ok, nil} ->
        fetch_and_cache_price(ticker)

      {:ok, price} ->
        {:ok, price}

      {:error, reason} = error ->
        Logger.error("Cachex error: #{inspect(reason)}")
        error
    end
  end

  # Private Functions

  defp fetch_and_cache_price(ticker) do
    case fetch_from_api(ticker) do
      {:ok, price} ->
        cache_price(ticker, price)
        {:ok, price}

      error ->
        error
    end
  end

  defp fetch_from_api(ticker) do
    api_url = get_api_url(ticker)
    Logger.info("Fetching latest index price from API: #{api_url}")

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(api_url, []) do
      {:ok, %{status: 200, body: body}} ->
        parse_api_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("API returned status #{status}: #{inspect(body)}")
        {:error, {:api_error, status}}

      {:error, reason} = error ->
        Logger.error("Failed to fetch latest index price: #{inspect(reason)}")
        error
    end
  end

  defp parse_api_response(%{
         "chart" => %{"result" => [%{"timestamp" => timestamps, "indicators" => indicators} | _]}
       }) do
    case indicators do
      %{"quote" => [%{"close" => closes} | _]} -> latest_valid_close(timestamps, closes)
      _ -> {:error, :invalid_response}
    end
  end

  defp parse_api_response(body) do
    Logger.error("Unexpected API response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  defp latest_valid_close(timestamps, closes) do
    timestamps
    |> Enum.zip(closes)
    |> Enum.reject(fn {_timestamp, close} -> is_nil(close) end)
    |> case do
      [] ->
        {:error, :no_valid_price}

      points ->
        {_timestamp, price} = Enum.max_by(points, fn {timestamp, _close} -> timestamp end)
        {:ok, price}
    end
  end

  defp cache_price(ticker, price) do
    case Cachex.put(@cache_name, ticker, price, ttl: @cache_ttl) do
      {:ok, true} ->
        Logger.info("Successfully cached #{ticker} price for #{@cache_ttl}ms")
        :ok

      {:error, reason} ->
        Logger.error("Failed to cache index price: #{inspect(reason)}")
        :error
    end
  end

  defp get_api_url(ticker) do
    period2 = DateTime.to_unix(DateTime.utc_now())
    period1 = period2 - @window_days * 24 * 60 * 60

    "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}?period1=#{period1}&period2=#{period2}&interval=1d"
  end
end
