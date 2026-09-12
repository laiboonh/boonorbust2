defmodule Boonorbust2.HistoricalIndexPricesTest do
  use Boonorbust2.DataCase, async: false

  import Mox

  alias Boonorbust2.HistoricalIndexPrices
  alias Boonorbust2.HTTPClientMock

  @date ~D[2024-01-15]
  @other_date ~D[2024-01-16]
  @ticker "VWRA.L"
  @other_ticker "CSPX.L"

  setup :verify_on_exit!

  describe "get_price/2" do
    @tag :capture_log
    test "fetches price from API on first call" do
      expect_chart_call(@ticker, [
        {date_timestamp(@date), 100.5}
      ])

      assert {:ok, price} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price == 100.5
    end

    @tag :capture_log
    test "uses persisted price on second call without calling API" do
      expect_chart_call(@ticker, [{date_timestamp(@date), 100.5}])
      assert {:ok, price1} = HistoricalIndexPrices.get_price(@date, @ticker)

      # Second call - no API call expected
      assert {:ok, price2} = HistoricalIndexPrices.get_price(@date, @ticker)

      assert price1 == price2
      assert price2 == 100.5
    end

    @tag :capture_log
    test "caches different tickers for the same date independently" do
      expect_chart_call(@ticker, [{date_timestamp(@date), 100.5}])
      assert {:ok, price} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price == 100.5

      expect_chart_call(@other_ticker, [{date_timestamp(@date), 50.0}])
      assert {:ok, other_price} = HistoricalIndexPrices.get_price(@date, @other_ticker)
      assert other_price == 50.0

      # Verify both remain persisted independently, no further API calls
      assert {:ok, price_cached} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price_cached == 100.5

      assert {:ok, other_price_cached} = HistoricalIndexPrices.get_price(@date, @other_ticker)
      assert other_price_cached == 50.0
    end

    @tag :capture_log
    test "caches different dates for the same ticker independently" do
      expect_chart_call(@ticker, [{date_timestamp(@date), 100.5}])
      assert {:ok, price} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price == 100.5

      expect_chart_call(@ticker, [{date_timestamp(@other_date), 101.2}])
      assert {:ok, other_price} = HistoricalIndexPrices.get_price(@other_date, @ticker)
      assert other_price == 101.2

      # First date's price remains unchanged and cached
      assert {:ok, price_cached} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price_cached == 100.5
    end

    @tag :capture_log
    test "snaps to the prior trading day when the requested date has no close" do
      friday = ~D[2024-01-12]
      saturday = ~D[2024-01-13]
      sunday = ~D[2024-01-14]

      expect_chart_call(@ticker, [
        {date_timestamp(friday), 99.0},
        {date_timestamp(saturday), nil},
        {date_timestamp(sunday), nil}
      ])

      assert {:ok, price} = HistoricalIndexPrices.get_price(sunday, @ticker)
      assert price == 99.0

      # Persisted under the originally requested date (sunday), so a repeat
      # lookup for sunday hits the DB directly with no further API call.
      assert {:ok, cached_price} = HistoricalIndexPrices.get_price(sunday, @ticker)
      assert cached_price == 99.0
    end

    @tag :capture_log
    test "ignores close prices after the requested date" do
      expect_chart_call(@ticker, [
        {date_timestamp(@date), 100.5},
        {date_timestamp(@other_date), 999.0}
      ])

      assert {:ok, price} = HistoricalIndexPrices.get_price(@date, @ticker)
      assert price == 100.5
    end

    @tag :capture_log
    test "handles API errors" do
      mock_api_error(@ticker, 500)

      assert {:error, {:api_error, 500}} = HistoricalIndexPrices.get_price(@date, @ticker)
    end

    @tag :capture_log
    test "handles network errors" do
      mock_network_error(@ticker)

      assert {:error, _reason} = HistoricalIndexPrices.get_price(@date, @ticker)
    end

    @tag :capture_log
    test "handles unexpected API response format" do
      HTTPClientMock
      |> expect(:get, fn url, _opts ->
        assert url_for_ticker?(url, @ticker)
        {:ok, %{status: 200, body: %{"unexpected" => "shape"}}}
      end)

      assert {:error, :invalid_response} = HistoricalIndexPrices.get_price(@date, @ticker)
    end

    @tag :capture_log
    test "returns error when no valid close exists on or before the requested date" do
      expect_chart_call(@ticker, [{date_timestamp(@date), nil}])

      assert {:error, :no_valid_price} = HistoricalIndexPrices.get_price(@date, @ticker)
    end
  end

  # Helper functions

  defp date_timestamp(date) do
    date
    |> DateTime.new!(~T[12:00:00], "Etc/UTC")
    |> DateTime.to_unix()
  end

  defp url_for_ticker?(url, ticker) do
    String.match?(
      url,
      ~r/^https:\/\/query1\.finance\.yahoo\.com\/v8\/finance\/chart\/#{Regex.escape(ticker)}\?period1=\d+&period2=\d+&interval=1d$/
    )
  end

  defp chart_response_body(points) do
    %{
      "chart" => %{
        "result" => [
          %{
            "timestamp" => Enum.map(points, fn {timestamp, _close} -> timestamp end),
            "indicators" => %{
              "quote" => [
                %{"close" => Enum.map(points, fn {_timestamp, close} -> close end)}
              ]
            }
          }
        ],
        "error" => nil
      }
    }
  end

  defp expect_chart_call(ticker, points) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_ticker?(url, ticker)
      {:ok, %{status: 200, body: chart_response_body(points)}}
    end)
  end

  defp mock_api_error(ticker, status) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_ticker?(url, ticker)
      {:ok, %{status: status, body: %{"error" => "server error"}}}
    end)
  end

  defp mock_network_error(ticker) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_ticker?(url, ticker)
      {:error, :network_error}
    end)
  end
end
