defmodule Boonorbust2.IrrTest do
  use Boonorbust2.DataCase, async: false

  import Mox

  alias Boonorbust2.Accounts
  alias Boonorbust2.Assets
  alias Boonorbust2.Dividends
  alias Boonorbust2.HTTPClientMock
  alias Boonorbust2.Irr
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.PortfolioTransactions
  alias Boonorbust2.RealizedProfits

  setup :verify_on_exit!

  describe "xirr/2" do
    test "returns the known rate for a simple invest-then-return-more cash flow" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("1200")}
      ]

      assert {:ok, rate} = Irr.xirr(cash_flows)
      assert_in_delta rate, 0.20, 0.0001
    end

    test "returns an error when all cash flows are the same sign" do
      cash_flows = [
        {~D[2024-01-01], Decimal.new("-1000")},
        {~D[2024-06-01], Decimal.new("-500")}
      ]

      assert Irr.xirr(cash_flows) == {:error, :no_sign_change}
    end

    test "returns an error for an empty list of cash flows" do
      assert Irr.xirr([]) == {:error, :no_sign_change}
    end

    test "returns an error when all cash flows fall on the same date" do
      same_date = ~D[2024-01-01]

      cash_flows = [
        {same_date, Decimal.new("-1000")},
        {same_date, Decimal.new("1000")}
      ]

      assert Irr.xirr(cash_flows) == {:error, :no_time_variance}
    end

    test "returns a negative rate for a net loss scenario" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("800")}
      ]

      assert {:ok, rate} = Irr.xirr(cash_flows)
      assert rate < 0
      assert_in_delta rate, -0.20, 0.0001
    end

    test "returns an explicit error instead of looping indefinitely when the iteration cap is hit" do
      start_date = ~D[2024-01-01]
      end_date = Date.add(start_date, 365)

      cash_flows = [
        {start_date, Decimal.new("-1000")},
        {end_date, Decimal.new("1200")}
      ]

      assert Irr.xirr(cash_flows, max_iterations: 0) == {:error, :max_iterations_exceeded}
    end
  end

  describe "calculate_portfolio_irr/1" do
    @tag :capture_log
    test "converts each historical flow at its own date's rate, includes dividend income, and contributes $0 for a fully-divested asset" do
      user = create_user("SGD")
      asset = create_asset("USD")

      {:ok, buy} =
        create_transaction(user.id, asset.id, "buy", "10", "100.00", ~U[2024-01-01 00:00:00Z])

      {:ok, sell} =
        create_transaction(user.id, asset.id, "sell", "10", "150.00", ~U[2024-06-01 00:00:00Z])

      {:ok, _} = PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      dividend = create_dividend(asset.id, ~D[2024-03-15], ~D[2024-04-01])

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:USD, "30.00")
        })

      # A capital gain record now exists for the sell — the test asserts below that it is
      # NOT reflected as an extra cash flow (the sell transaction's amount already is one).
      assert RealizedProfits.get_realized_profit_by_transaction(sell.id) != nil

      # Transactions are converted first (in transaction_date order), then dividends —
      # expectations must be declared in that same call order.
      expect_historical_rate(~D[2024-01-01], "USD", %{"SGD" => 1.30})
      expect_historical_rate(~D[2024-06-01], "USD", %{"SGD" => 1.35})
      expect_historical_rate(~D[2024-04-01], "USD", %{"SGD" => 1.32})

      seed_live_usd_rate(1.30)

      expected_cash_flows = [
        {~D[2024-01-01], Decimal.new("-1300.00")},
        {~D[2024-04-01], Decimal.new("39.60")},
        {~D[2024-06-01], Decimal.new("2025.00")},
        {Date.utc_today(), Decimal.new(0)}
      ]

      assert {:ok, expected_rate} = Irr.xirr(expected_cash_flows)
      assert {:ok, actual_rate} = Irr.calculate_portfolio_irr(user.id)
      assert_in_delta actual_rate, expected_rate, 0.0001

      _ = buy
    end

    @tag :capture_log
    test "fails the whole calculation without falling back when a historical rate fetch fails" do
      user = create_user("SGD")
      asset = create_asset("USD")

      {:ok, _buy} =
        create_transaction(user.id, asset.id, "buy", "10", "100.00", ~U[2024-01-01 00:00:00Z])

      {:ok, _} = PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      expect_historical_rate_error(~D[2024-01-01], "USD")

      assert {:error, _reason} = Irr.calculate_portfolio_irr(user.id)
    end
  end

  describe "calculate_benchmark_irr/1" do
    @tag :capture_log
    test "replays real cash flows into a hypothetical VWRA position and XIRRs the result" do
      user = create_user("USD")
      asset = create_asset("USD")

      {:ok, buy} =
        create_transaction(user.id, asset.id, "buy", "10", "100.00", ~U[2024-01-01 00:00:00Z])

      {:ok, sell} =
        create_transaction(user.id, asset.id, "sell", "10", "150.00", ~U[2024-06-01 00:00:00Z])

      {:ok, _} = PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      dividend = create_dividend(asset.id, ~D[2024-03-15], ~D[2024-04-01])

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:USD, "22.00")
        })

      # Real cash flows (buy: -1000, dividend: +22, sell: +1500), in the same order
      # calculate_benchmark_irr replays them: transactions first, then dividends.
      expect_vwra_price(~D[2024-01-01], 100.0)
      expect_vwra_price(~D[2024-06-01], 200.0)
      expect_vwra_price(~D[2024-04-01], 110.0)
      expect_latest_vwra_price(200.0)

      # Hand-worked VWRA unit tracking (units_delta = -usd_amount / price_on_date):
      #   buy:      -(-1000.00) / 100.0 = +10.0     (running total: 10.0)
      #   dividend: -(  22.00) / 110.0 = -0.2        (running total: 9.8)
      #   sell:     -( 1500.00) / 200.0 = -7.5        (running total: 2.3)
      # Terminal value: 2.3 units * 200.0 (today's live price) = 460.00
      expected_cash_flows = [
        {~D[2024-01-01], Decimal.new("-1000.00")},
        {~D[2024-04-01], Decimal.new("22.00")},
        {~D[2024-06-01], Decimal.new("1500.00")},
        {Date.utc_today(), Decimal.new("460.00")}
      ]

      assert {:ok, expected_rate} = Irr.xirr(expected_cash_flows)
      assert {:ok, actual_rate} = Irr.calculate_benchmark_irr(user.id)
      assert_in_delta actual_rate, expected_rate, 0.0001

      _ = buy
      _ = sell
    end

    @tag :capture_log
    test "fails the whole calculation without falling back when a VWRA price fetch fails" do
      user = create_user("USD")
      asset = create_asset("USD")

      {:ok, _buy} =
        create_transaction(user.id, asset.id, "buy", "10", "100.00", ~U[2024-01-01 00:00:00Z])

      {:ok, _} = PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      expect_vwra_price_error(~D[2024-01-01])

      assert {:error, _reason} = Irr.calculate_benchmark_irr(user.id)
    end
  end

  # Helper functions

  defp create_user(currency) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "user-#{System.unique_integer([:positive])}@example.com",
        name: "Test User",
        provider: "google",
        uid: "uid-#{System.unique_integer([:positive])}",
        currency: currency
      })

    user
  end

  defp create_asset(currency) do
    {:ok, asset} =
      Assets.create_asset(%{
        code: "ASSET#{System.unique_integer([:positive])}",
        name: "Test Asset",
        currency: currency
      })

    asset
  end

  defp create_transaction(user_id, asset_id, action, quantity, price, transaction_date) do
    PortfolioTransactions.create_portfolio_transaction(%{
      "user_id" => user_id,
      "asset_id" => asset_id,
      "action" => action,
      "quantity" => quantity,
      "price" => price,
      "commission" => "0.00",
      "currency" => "USD",
      "transaction_date" => transaction_date
    })
  end

  defp create_dividend(asset_id, ex_date, pay_date) do
    {:ok, dividend} =
      Dividends.create_dividend(%{
        asset_id: asset_id,
        ex_date: ex_date,
        pay_date: pay_date,
        value: Decimal.new("1.00"),
        currency: "USD"
      })

    dividend
  end

  defp expect_historical_rate(date, base_currency, rates) do
    url =
      "https://api.frankfurter.dev/v2/rates?date=#{Date.to_iso8601(date)}&base=#{base_currency}"

    response_body =
      Enum.map(rates, fn {quote_currency, rate} ->
        %{
          "date" => Date.to_iso8601(date),
          "base" => base_currency,
          "quote" => quote_currency,
          "rate" => rate
        }
      end)

    HTTPClientMock
    |> expect(:get, fn ^url, _opts -> {:ok, %{status: 200, body: response_body}} end)
  end

  defp expect_historical_rate_error(date, base_currency) do
    url =
      "https://api.frankfurter.dev/v2/rates?date=#{Date.to_iso8601(date)}&base=#{base_currency}"

    HTTPClientMock
    |> expect(:get, fn ^url, _opts -> {:error, :network_error} end)
  end

  defp seed_live_usd_rate(rate) do
    Cachex.put(:exchange_rates_cache, "usd_rates", %{"SGD" => rate})
    on_exit(fn -> Cachex.del(:exchange_rates_cache, "usd_rates") end)
  end

  defp expect_vwra_price(date, price) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:ok, %{status: 200, body: chart_response_body(date, price)}}
    end)
  end

  defp expect_vwra_price_error(_date) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:error, :network_error}
    end)
  end

  defp expect_latest_vwra_price(price) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:ok, %{status: 200, body: chart_response_body(Date.utc_today(), price)}}
    end)
  end

  defp url_for_vwra?(url) do
    String.match?(
      url,
      ~r/^https:\/\/query1\.finance\.yahoo\.com\/v8\/finance\/chart\/VWRA\.L\?period1=\d+&period2=\d+&interval=1d$/
    )
  end

  defp chart_response_body(date, price) do
    timestamp = date |> DateTime.new!(~T[12:00:00], "Etc/UTC") |> DateTime.to_unix()

    %{
      "chart" => %{
        "result" => [
          %{
            "timestamp" => [timestamp],
            "indicators" => %{"quote" => [%{"close" => [price]}]}
          }
        ]
      }
    }
  end
end
