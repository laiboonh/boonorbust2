defmodule Boonorbust2.HistoricalIndexPrices do
  @moduledoc """
  Fetches and persists historical closing prices for an index/ETF ticker from
  Yahoo Finance's chart API.

  Unlike `Boonorbust2.IndexPrices` (which caches today's price with a 1-hour
  TTL), historical prices never change once the trading day has closed, so
  they are persisted forever in the `historical_index_prices` table, keyed on
  `(date, ticker)`.

  Weekends/holidays are not trading days, so on a cache miss a trailing
  window is fetched and the latest trading day's close `<=` the requested
  date is used, then persisted under the originally requested date so
  repeat lookups hit the cache directly.
  """

  require Logger

  alias Boonorbust2.HistoricalIndexPrices.HistoricalIndexPrice
  alias Boonorbust2.Repo

  # Trailing window in days to absorb weekends/holidays with no trading activity
  @window_days 10

  @doc """
  Gets the historical closing price for the given date and ticker.

  Returns the persisted price if already fetched, otherwise fetches from
  Yahoo Finance's chart API, snaps to the latest trading day `<=` date, and
  persists the result under `date` forever.

  Returns `{:ok, price}` on success or `{:error, reason}` on failure.
  """
  @spec get_price(Date.t(), String.t()) :: {:ok, float()} | {:error, term()}
  def get_price(date, ticker) when is_binary(ticker) do
    case get_persisted_price(date, ticker) do
      %HistoricalIndexPrice{close: close} ->
        {:ok, close}

      nil ->
        fetch_and_persist_price(date, ticker)
    end
  end

  # Private Functions

  defp get_persisted_price(date, ticker) do
    Repo.get_by(HistoricalIndexPrice, date: date, ticker: ticker)
  end

  defp fetch_and_persist_price(date, ticker) do
    case fetch_from_api(date, ticker) do
      {:ok, price} ->
        persist_price(date, ticker, price)
        {:ok, price}

      error ->
        error
    end
  end

  defp fetch_from_api(date, ticker) do
    api_url = get_api_url(date, ticker)
    Logger.info("Fetching historical index price from API: #{api_url}")

    http_client =
      Application.get_env(:boonorbust2, :http_client, Boonorbust2.HTTPClient.ReqAdapter)

    case http_client.get(api_url, []) do
      {:ok, %{status: 200, body: body}} ->
        parse_api_response(body, date)

      {:ok, %{status: status, body: body}} ->
        Logger.error("API returned status #{status}: #{inspect(body)}")
        {:error, {:api_error, status}}

      {:error, reason} = error ->
        Logger.error("Failed to fetch historical index price: #{inspect(reason)}")
        error
    end
  end

  defp parse_api_response(
         %{
           "chart" => %{
             "result" => [%{"timestamp" => timestamps, "indicators" => indicators} | _]
           }
         },
         date
       ) do
    case indicators do
      %{"quote" => [%{"close" => closes} | _]} ->
        latest_valid_close_on_or_before(timestamps, closes, date)

      _ ->
        {:error, :invalid_response}
    end
  end

  defp parse_api_response(body, _date) do
    Logger.error("Unexpected API response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  defp latest_valid_close_on_or_before(timestamps, closes, date) do
    timestamps
    |> Enum.zip(closes)
    |> Enum.reject(fn {timestamp, close} ->
      is_nil(close) or Date.after?(timestamp_to_date(timestamp), date)
    end)
    |> case do
      [] ->
        {:error, :no_valid_price}

      points ->
        {_timestamp, price} = Enum.max_by(points, fn {timestamp, _close} -> timestamp end)
        {:ok, price}
    end
  end

  defp timestamp_to_date(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_date()
  end

  defp persist_price(date, ticker, price) do
    attrs = %{date: date, ticker: ticker, close: price}

    %HistoricalIndexPrice{}
    |> HistoricalIndexPrice.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:date, :ticker])
  end

  defp get_api_url(date, ticker) do
    period1 =
      DateTime.new!(Date.add(date, -@window_days), ~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()

    period2 = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()

    "https://query1.finance.yahoo.com/v8/finance/chart/#{ticker}?period1=#{period1}&period2=#{period2}&interval=1d"
  end
end
