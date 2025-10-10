defmodule Boonorbust2.ExchangeRatesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Boonorbust2.ExchangeRates
  alias Boonorbust2.HTTPClientMock

  @api_key "test_api_key"
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

  setup do
    # Clear cache before each test
    Cachex.clear(:exchange_rates_cache)

    # Set test API key
    Application.put_env(:boonorbust2, :exchange_rate_api_key, @api_key)

    :ok
  end

  describe "get_rates/1" do
    @tag :capture_log
    test "fetches rates from API on first call" do
      # Mock the HTTP request
      expect_api_call("USD", @usd_rates)

      assert {:ok, rates} = ExchangeRates.get_rates("USD")
      assert rates == @usd_rates
    end

    @tag :capture_log
    test "uses cache on second call without calling API" do
      # First call - should hit API
      expect_api_call("USD", @usd_rates)
      assert {:ok, rates1} = ExchangeRates.get_rates("USD")

      # Second call - should use cache, no API call expected
      assert {:ok, rates2} = ExchangeRates.get_rates("USD")

      # Both should return same data
      assert rates1 == rates2
      assert rates2 == @usd_rates
    end

    @tag :capture_log
    test "caches different base currencies separately" do
      # Mock USD rates
      expect_api_call("USD", @usd_rates)
      assert {:ok, usd_rates} = ExchangeRates.get_rates("USD")
      assert usd_rates == @usd_rates

      # Mock SGD rates - should make another API call
      expect_api_call("SGD", @sgd_rates)
      assert {:ok, sgd_rates} = ExchangeRates.get_rates("SGD")
      assert sgd_rates == @sgd_rates

      # Verify USD cache still works (no API call)
      assert {:ok, usd_rates_cached} = ExchangeRates.get_rates("USD")
      assert usd_rates_cached == @usd_rates

      # Verify SGD cache still works (no API call)
      assert {:ok, sgd_rates_cached} = ExchangeRates.get_rates("SGD")
      assert sgd_rates_cached == @sgd_rates
    end

    @tag :capture_log
    test "defaults to USD when no currency specified" do
      expect_api_call("USD", @usd_rates)

      assert {:ok, rates} = ExchangeRates.get_rates()
      assert rates == @usd_rates
    end

    @tag :capture_log
    test "handles API errors" do
      mock_api_error("USD", 401)

      assert {:error, {:api_error, 401}} = ExchangeRates.get_rates("USD")
    end

    @tag :capture_log
    test "handles network errors" do
      mock_network_error("USD")

      assert {:error, _reason} = ExchangeRates.get_rates("USD")
    end
  end

  describe "get_rate/2" do
    @tag :capture_log
    test "fetches specific currency rate" do
      expect_api_call("USD", @usd_rates)

      assert {:ok, rate} = ExchangeRates.get_rate("USD", "SGD")
      assert rate == 1.35
    end

    @tag :capture_log
    test "uses cached rates for subsequent calls" do
      expect_api_call("USD", @usd_rates)

      # First call
      assert {:ok, rate1} = ExchangeRates.get_rate("USD", "SGD")

      # Second call - should use cache
      assert {:ok, rate2} = ExchangeRates.get_rate("USD", "EUR")

      assert rate1 == 1.35
      assert rate2 == 0.92
    end

    @tag :capture_log
    test "returns error for non-existent currency" do
      expect_api_call("USD", @usd_rates)

      assert {:error, :currency_not_found} = ExchangeRates.get_rate("USD", "XYZ")
    end
  end

  describe "refresh/1" do
    @tag :capture_log
    test "clears cache and fetches fresh data from API" do
      # First call - populate cache
      expect_api_call("USD", @usd_rates)
      assert {:ok, _rates} = ExchangeRates.get_rates("USD")

      # Second call - should use cache (no API call expected here)
      assert {:ok, _rates} = ExchangeRates.get_rates("USD")

      # Refresh - should clear cache and call API again
      new_rates = %{@usd_rates | "SGD" => 1.40}
      expect_api_call("USD", new_rates)
      assert {:ok, refreshed_rates} = ExchangeRates.refresh("USD")
      assert refreshed_rates["SGD"] == 1.40
    end

    @tag :capture_log
    test "refreshing one currency doesn't affect other currency caches" do
      # Cache USD rates
      expect_api_call("USD", @usd_rates)
      assert {:ok, _} = ExchangeRates.get_rates("USD")

      # Cache SGD rates
      expect_api_call("SGD", @sgd_rates)
      assert {:ok, _} = ExchangeRates.get_rates("SGD")

      # Refresh USD only
      new_usd_rates = %{@usd_rates | "SGD" => 1.40}
      expect_api_call("USD", new_usd_rates)
      assert {:ok, _} = ExchangeRates.refresh("USD")

      # SGD cache should still work (no API call)
      assert {:ok, sgd_rates} = ExchangeRates.get_rates("SGD")
      assert sgd_rates == @sgd_rates
    end

    @tag :capture_log
    test "defaults to USD when no currency specified" do
      expect_api_call("USD", @usd_rates)

      assert {:ok, rates} = ExchangeRates.refresh()
      assert rates == @usd_rates
    end
  end

  # Helper functions

  defp expect_api_call(currency, rates) do
    response_body = %{
      "result" => "success",
      "conversion_rates" => rates
    }

    expected_url = "https://v6.exchangerate-api.com/v6/#{@api_key}/latest/#{currency}"

    HTTPClientMock
    |> expect(:get, fn ^expected_url, _opts ->
      {:ok, %{status: 200, body: response_body}}
    end)
  end

  defp mock_api_error(currency, status) do
    expected_url = "https://v6.exchangerate-api.com/v6/#{@api_key}/latest/#{currency}"

    HTTPClientMock
    |> expect(:get, fn ^expected_url, _opts ->
      {:ok, %{status: status, body: %{"error" => "Unauthorized"}}}
    end)
  end

  defp mock_network_error(currency) do
    expected_url = "https://v6.exchangerate-api.com/v6/#{@api_key}/latest/#{currency}"

    HTTPClientMock
    |> expect(:get, fn ^expected_url, _opts ->
      {:error, :network_error}
    end)
  end
end
