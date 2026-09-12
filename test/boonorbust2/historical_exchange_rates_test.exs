defmodule Boonorbust2.HistoricalExchangeRatesTest do
  use Boonorbust2.DataCase, async: false

  import Mox

  alias Boonorbust2.HistoricalExchangeRates
  alias Boonorbust2.HTTPClientMock

  @date ~D[2024-01-15]
  @other_date ~D[2024-01-16]
  @usd_rates %{
    "SGD" => 1.35,
    "EUR" => 0.92,
    "GBP" => 0.79,
    "HKD" => 7.85
  }
  @sgd_rates %{
    "USD" => 0.74,
    "EUR" => 0.68,
    "GBP" => 0.58,
    "HKD" => 5.81
  }

  setup :verify_on_exit!

  describe "get_rates/2" do
    @tag :capture_log
    test "fetches rates from API on first call" do
      expect_api_call(@date, "USD", @usd_rates)

      assert {:ok, rates} = HistoricalExchangeRates.get_rates(@date, "USD")
      assert rates == @usd_rates
    end

    @tag :capture_log
    test "uses persisted rates on second call without calling API" do
      expect_api_call(@date, "USD", @usd_rates)
      assert {:ok, rates1} = HistoricalExchangeRates.get_rates(@date, "USD")

      # Second call - no API call expected
      assert {:ok, rates2} = HistoricalExchangeRates.get_rates(@date, "USD")

      assert rates1 == rates2
      assert rates2 == @usd_rates
    end

    @tag :capture_log
    test "caches different base currencies for the same date independently" do
      expect_api_call(@date, "USD", @usd_rates)
      assert {:ok, usd_rates} = HistoricalExchangeRates.get_rates(@date, "USD")
      assert usd_rates == @usd_rates

      expect_api_call(@date, "SGD", @sgd_rates)
      assert {:ok, sgd_rates} = HistoricalExchangeRates.get_rates(@date, "SGD")
      assert sgd_rates == @sgd_rates

      # Verify both remain persisted independently, no further API calls
      assert {:ok, usd_rates_cached} = HistoricalExchangeRates.get_rates(@date, "USD")
      assert usd_rates_cached == @usd_rates

      assert {:ok, sgd_rates_cached} = HistoricalExchangeRates.get_rates(@date, "SGD")
      assert sgd_rates_cached == @sgd_rates
    end

    @tag :capture_log
    test "caches different dates for the same base currency independently" do
      expect_api_call(@date, "USD", @usd_rates)
      assert {:ok, rates} = HistoricalExchangeRates.get_rates(@date, "USD")
      assert rates == @usd_rates

      new_rates = %{@usd_rates | "SGD" => 1.40}
      expect_api_call(@other_date, "USD", new_rates)
      assert {:ok, other_rates} = HistoricalExchangeRates.get_rates(@other_date, "USD")
      assert other_rates == new_rates

      # First date's rates remain unchanged and cached
      assert {:ok, rates_cached} = HistoricalExchangeRates.get_rates(@date, "USD")
      assert rates_cached == @usd_rates
    end

    @tag :capture_log
    test "handles API errors" do
      mock_api_error(@date, "USD", 400)

      assert {:error, {:api_error, 400}} = HistoricalExchangeRates.get_rates(@date, "USD")
    end

    @tag :capture_log
    test "handles network errors" do
      mock_network_error(@date, "USD")

      assert {:error, _reason} = HistoricalExchangeRates.get_rates(@date, "USD")
    end
  end

  # Helper functions

  defp expected_url(date, currency) do
    "https://api.frankfurter.dev/v2/rates?date=#{Date.to_iso8601(date)}&base=#{currency}"
  end

  defp expect_api_call(date, currency, rates) do
    response_body = %{
      "amount" => 1,
      "base" => currency,
      "date" => Date.to_iso8601(date),
      "rates" => rates
    }

    url = expected_url(date, currency)

    HTTPClientMock
    |> expect(:get, fn ^url, _opts ->
      {:ok, %{status: 200, body: response_body}}
    end)
  end

  defp mock_api_error(date, currency, status) do
    url = expected_url(date, currency)

    HTTPClientMock
    |> expect(:get, fn ^url, _opts ->
      {:ok, %{status: status, body: %{"message" => "Bad Request"}}}
    end)
  end

  defp mock_network_error(date, currency) do
    url = expected_url(date, currency)

    HTTPClientMock
    |> expect(:get, fn ^url, _opts ->
      {:error, :network_error}
    end)
  end
end
