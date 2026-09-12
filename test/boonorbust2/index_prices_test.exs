defmodule Boonorbust2.IndexPricesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Boonorbust2.HTTPClientMock
  alias Boonorbust2.IndexPrices

  @ticker "VWRA.L"
  @other_ticker "CSPX.L"

  setup :verify_on_exit!

  setup do
    Cachex.clear(:index_prices_cache)
    :ok
  end

  describe "get_latest_price/1" do
    @tag :capture_log
    test "fetches latest price from API on first call" do
      expect_chart_call(@ticker, [{1_700_000_000, 100.5}, {1_700_086_400, 101.2}])

      assert {:ok, price} = IndexPrices.get_latest_price(@ticker)
      assert price == 101.2
    end

    @tag :capture_log
    test "uses cache on second call without calling API" do
      expect_chart_call(@ticker, [{1_700_000_000, 100.5}, {1_700_086_400, 101.2}])
      assert {:ok, price1} = IndexPrices.get_latest_price(@ticker)

      assert {:ok, price2} = IndexPrices.get_latest_price(@ticker)

      assert price1 == price2
      assert price2 == 101.2
    end

    @tag :capture_log
    test "caches different tickers separately" do
      expect_chart_call(@ticker, [{1_700_000_000, 100.5}])
      assert {:ok, price} = IndexPrices.get_latest_price(@ticker)
      assert price == 100.5

      expect_chart_call(@other_ticker, [{1_700_000_000, 50.0}])
      assert {:ok, other_price} = IndexPrices.get_latest_price(@other_ticker)
      assert other_price == 50.0

      # Verify both remain cached independently, no further API calls
      assert {:ok, price_cached} = IndexPrices.get_latest_price(@ticker)
      assert price_cached == 100.5

      assert {:ok, other_price_cached} = IndexPrices.get_latest_price(@other_ticker)
      assert other_price_cached == 50.0
    end

    @tag :capture_log
    test "skips null closes and returns the latest valid close" do
      expect_chart_call(@ticker, [
        {1_700_000_000, 100.5},
        {1_700_086_400, nil}
      ])

      assert {:ok, price} = IndexPrices.get_latest_price(@ticker)
      assert price == 100.5
    end

    @tag :capture_log
    test "returns error when no valid close exists in the window" do
      expect_chart_call(@ticker, [{1_700_000_000, nil}, {1_700_086_400, nil}])

      assert {:error, :no_valid_price} = IndexPrices.get_latest_price(@ticker)
    end

    @tag :capture_log
    test "handles API errors" do
      mock_api_error(@ticker, 500)

      assert {:error, {:api_error, 500}} = IndexPrices.get_latest_price(@ticker)
    end

    @tag :capture_log
    test "handles network errors" do
      mock_network_error(@ticker)

      assert {:error, _reason} = IndexPrices.get_latest_price(@ticker)
    end

    @tag :capture_log
    test "handles unexpected API response format" do
      HTTPClientMock
      |> expect(:get, fn url, _opts ->
        assert url_for_ticker?(url, @ticker)
        {:ok, %{status: 200, body: %{"unexpected" => "shape"}}}
      end)

      assert {:error, :invalid_response} = IndexPrices.get_latest_price(@ticker)
    end
  end

  # Helper functions

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
