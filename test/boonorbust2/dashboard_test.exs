defmodule Boonorbust2.DashboardTest do
  use Boonorbust2.DataCase, async: true

  alias Boonorbust2.Accounts
  alias Boonorbust2.Assets
  alias Boonorbust2.Dashboard
  alias Boonorbust2.Dividends
  alias Boonorbust2.RealizedProfits

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        provider: "google",
        uid: "test123",
        currency: "SGD"
      })

    %{user: user}
  end

  describe "prepare_dividend_chart_data/2 - avg_monthly_income" do
    test "returns 0.0 when user has no dividend records", %{user: user} do
      result = Dashboard.prepare_dividend_chart_data(user.id, "SGD")

      assert result.avg_monthly_income == 0.0
    end

    test "returns total income when all dividends fall in a single month", %{user: user} do
      asset = create_asset("AAPL", "Apple Inc.", "SGD")

      dividend1 = create_dividend(asset.id, ~D[2025-01-10], "SGD")
      create_realized_profit(user.id, asset.id, dividend1.id, "100.00", "SGD")

      dividend2 = create_dividend(asset.id, ~D[2025-01-25], "SGD")
      create_realized_profit(user.id, asset.id, dividend2.id, "50.00", "SGD")

      result = Dashboard.prepare_dividend_chart_data(user.id, "SGD")

      # Single month: avg = total / 1 = 150.00
      assert_in_delta result.avg_monthly_income, 150.0, 0.01
    end

    test "averages income across multiple months", %{user: user} do
      asset = create_asset("AAPL", "Apple Inc.", "SGD")

      dividend_jan = create_dividend(asset.id, ~D[2025-01-15], "SGD")
      create_realized_profit(user.id, asset.id, dividend_jan.id, "100.00", "SGD")

      dividend_feb = create_dividend(asset.id, ~D[2025-02-15], "SGD")
      create_realized_profit(user.id, asset.id, dividend_feb.id, "200.00", "SGD")

      dividend_mar = create_dividend(asset.id, ~D[2025-03-15], "SGD")
      create_realized_profit(user.id, asset.id, dividend_mar.id, "300.00", "SGD")

      result = Dashboard.prepare_dividend_chart_data(user.id, "SGD")

      # (100 + 200 + 300) / 3 months = 200.0
      assert_in_delta result.avg_monthly_income, 200.0, 0.01
    end

    test "sums multiple assets in the same month before averaging", %{user: user} do
      asset1 = create_asset("AAPL", "Apple Inc.", "SGD")
      asset2 = create_asset("MSFT", "Microsoft", "SGD")

      dividend1 = create_dividend(asset1.id, ~D[2025-01-15], "SGD")
      create_realized_profit(user.id, asset1.id, dividend1.id, "100.00", "SGD")

      dividend2 = create_dividend(asset2.id, ~D[2025-01-20], "SGD")
      create_realized_profit(user.id, asset2.id, dividend2.id, "80.00", "SGD")

      result = Dashboard.prepare_dividend_chart_data(user.id, "SGD")

      # Single month with two assets: avg = (100 + 80) / 1 = 180.0
      assert_in_delta result.avg_monthly_income, 180.0, 0.01
    end
  end

  # Helper functions

  defp create_asset(code, name, currency) do
    {:ok, asset} = Assets.create_asset(%{code: code, name: name, currency: currency})
    asset
  end

  defp create_dividend(asset_id, pay_date, currency) do
    ex_date = Date.add(pay_date, -14)

    {:ok, dividend} =
      Dividends.create_dividend(%{
        asset_id: asset_id,
        ex_date: ex_date,
        pay_date: pay_date,
        value: Decimal.new("1.00"),
        currency: currency
      })

    dividend
  end

  defp create_realized_profit(user_id, asset_id, dividend_id, amount, currency) do
    {:ok, rp} =
      RealizedProfits.upsert_dividend_income(%{
        user_id: user_id,
        asset_id: asset_id,
        dividend_id: dividend_id,
        amount: %{amount: amount, currency: currency}
      })

    rp
  end
end
