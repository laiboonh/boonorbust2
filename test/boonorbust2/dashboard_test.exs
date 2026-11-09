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

  describe "calculate_rebalance_suggestions/3" do
    test "underweight tag produces a buy, overweight tag produces a sell" do
      tags = [rebalance_tag(1, "Equity", "70"), rebalance_tag(2, "Bonds", "30")]
      positions = [rebalance_position([1], "50.00"), rebalance_position([2], "50.00")]

      result = Dashboard.calculate_rebalance_suggestions(tags, positions, "SGD")

      assert [
               %{label: "Equity", action: :buy, amount: buy},
               %{label: "Bonds", action: :sell, amount: sell}
             ] = result

      assert Decimal.equal?(buy.amount, Decimal.new("20.00"))
      assert Decimal.equal?(sell.amount, Decimal.new("20.00"))
    end

    test "tag exactly at target is omitted" do
      tags = [rebalance_tag(1, "Equity", "70"), rebalance_tag(2, "Bonds", "30")]
      positions = [rebalance_position([1], "70.00"), rebalance_position([2], "30.00")]

      assert Dashboard.calculate_rebalance_suggestions(tags, positions, "SGD") == []
    end

    test "zero-value tag with nonzero target produces a full-amount buy, not dropped" do
      tags = [rebalance_tag(1, "Equity", "70"), rebalance_tag(2, "Bonds", "30")]
      positions = [rebalance_position([1], "100.00")]

      result = Dashboard.calculate_rebalance_suggestions(tags, positions, "SGD")

      assert Enum.any?(result, fn suggestion ->
               suggestion.label == "Bonds" and suggestion.action == :buy and
                 Decimal.equal?(suggestion.amount.amount, Decimal.new("30.00"))
             end)
    end

    test "all-zero current values returns empty list" do
      tags = [rebalance_tag(1, "Equity", "70"), rebalance_tag(2, "Bonds", "30")]

      assert Dashboard.calculate_rebalance_suggestions(tags, [], "SGD") == []
    end

    test "tag with no target allocation set is skipped instead of crashing" do
      tags = [
        rebalance_tag(1, "Equity", "70"),
        rebalance_tag(2, "Bonds", "30"),
        %{id: 3, name: "Legacy", target_allocation_percent: nil}
      ]

      positions = [
        rebalance_position([1], "50.00"),
        rebalance_position([2], "50.00"),
        rebalance_position([3], "25.00")
      ]

      result = Dashboard.calculate_rebalance_suggestions(tags, positions, "SGD")

      assert Enum.map(result, & &1.label) |> Enum.sort() == ["Bonds", "Equity"]
    end

    test "orders all buys before all sells, each sorted descending by amount" do
      tags = [
        rebalance_tag(1, "A", "40"),
        rebalance_tag(2, "B", "30"),
        rebalance_tag(3, "C", "20"),
        rebalance_tag(4, "D", "10")
      ]

      positions = [
        rebalance_position([1], "10.00"),
        rebalance_position([2], "25.00"),
        rebalance_position([3], "40.00"),
        rebalance_position([4], "45.00")
      ]

      result = Dashboard.calculate_rebalance_suggestions(tags, positions, "SGD")

      assert Enum.map(result, & &1.label) == ["A", "B", "D", "C"]
      assert Enum.map(result, & &1.action) == [:buy, :buy, :sell, :sell]
    end
  end

  # Helper functions

  defp rebalance_tag(id, name, percent) do
    %{id: id, name: name, target_allocation_percent: Decimal.new(percent)}
  end

  defp rebalance_position(tag_ids, amount) do
    %{
      tags: Enum.map(tag_ids, &%{id: &1}),
      converted_total_value: Money.new!(Decimal.new(amount), "SGD")
    }
  end

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
