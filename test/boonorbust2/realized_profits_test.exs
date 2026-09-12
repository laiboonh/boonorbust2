defmodule Boonorbust2.RealizedProfitsTest do
  use Boonorbust2.DataCase, async: true

  alias Boonorbust2.Accounts
  alias Boonorbust2.Assets
  alias Boonorbust2.Dividends
  alias Boonorbust2.PortfolioTransactions
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

    {:ok, asset} =
      Assets.create_asset(%{code: "AAPL", name: "Apple Inc.", currency: "SGD"})

    %{user: user, asset: asset}
  end

  describe "upsert_capital_gain/1" do
    test "creates a new capital gain record", %{user: user, asset: asset} do
      txn = create_sell_transaction(user.id, asset.id)

      {:ok, rp} =
        RealizedProfits.upsert_capital_gain(%{
          user_id: user.id,
          asset_id: asset.id,
          portfolio_transaction_id: txn.id,
          amount: Money.new(:SGD, "500.00")
        })

      assert Money.equal?(rp.amount, Money.new(:SGD, "500.00"))
      assert rp.portfolio_transaction_id == txn.id
      assert rp.dividend_id == nil
    end

    test "upserts — calling twice with same transaction replaces amount", %{
      user: user,
      asset: asset
    } do
      txn = create_sell_transaction(user.id, asset.id)

      {:ok, _} =
        RealizedProfits.upsert_capital_gain(%{
          user_id: user.id,
          asset_id: asset.id,
          portfolio_transaction_id: txn.id,
          amount: Money.new(:SGD, "500.00")
        })

      {:ok, updated} =
        RealizedProfits.upsert_capital_gain(%{
          user_id: user.id,
          asset_id: asset.id,
          portfolio_transaction_id: txn.id,
          amount: Money.new(:SGD, "750.00")
        })

      assert Money.equal?(updated.amount, Money.new(:SGD, "750.00"))
      assert length(RealizedProfits.list_realized_profits_by_asset(asset.id, user.id)) == 1
    end
  end

  describe "upsert_dividend_income/1" do
    test "creates a new dividend income record", %{user: user, asset: asset} do
      dividend = create_dividend(asset.id)

      {:ok, rp} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:SGD, "100.00")
        })

      assert Money.equal?(rp.amount, Money.new(:SGD, "100.00"))
      assert rp.dividend_id == dividend.id
      assert rp.portfolio_transaction_id == nil
    end

    test "upserts — calling twice with same (user, dividend) replaces amount", %{
      user: user,
      asset: asset
    } do
      dividend = create_dividend(asset.id)

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:SGD, "100.00")
        })

      {:ok, updated} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:SGD, "150.00")
        })

      assert Money.equal?(updated.amount, Money.new(:SGD, "150.00"))
      assert length(RealizedProfits.list_realized_profits_by_asset(asset.id, user.id)) == 1
    end

    test "different users get separate records for the same dividend", %{
      user: user,
      asset: asset
    } do
      {:ok, user2} =
        Accounts.create_user(%{
          email: "other@example.com",
          name: "Other User",
          provider: "google",
          uid: "other456",
          currency: "SGD"
        })

      dividend = create_dividend(asset.id)

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:SGD, "100.00")
        })

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user2.id,
          asset_id: asset.id,
          dividend_id: dividend.id,
          amount: Money.new(:SGD, "200.00")
        })

      assert length(RealizedProfits.list_realized_profits_by_asset(asset.id, user.id)) == 1
      assert length(RealizedProfits.list_realized_profits_by_asset(asset.id, user2.id)) == 1
    end
  end

  describe "list_dividend_income_by_user/1" do
    test "excludes dividend income whose dividend has no pay_date yet", %{
      user: user,
      asset: asset
    } do
      paid_dividend = create_dividend(asset.id)

      {:ok, unpaid_dividend} =
        Dividends.create_dividend(%{
          asset_id: asset.id,
          ex_date: ~D[2024-04-01],
          pay_date: nil,
          value: Decimal.new("1.00"),
          currency: "SGD"
        })

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: paid_dividend.id,
          amount: Money.new(:SGD, "100.00")
        })

      {:ok, _} =
        RealizedProfits.upsert_dividend_income(%{
          user_id: user.id,
          asset_id: asset.id,
          dividend_id: unpaid_dividend.id,
          amount: Money.new(:SGD, "200.00")
        })

      results = RealizedProfits.list_dividend_income_by_user(user.id)

      assert [realized_profit] = results
      assert realized_profit.dividend_id == paid_dividend.id
    end
  end

  describe "process_dividend_for_all_users/1" do
    test "uses the final cumulative quantity when two buys share the same transaction_date",
         %{user: user, asset: asset} do
      # Two buys on exactly the same transaction_date, both before the dividend's ex-date.
      # Each produces its own position row (100, then 150 cumulative) sharing that date.
      {:ok, _} =
        PortfolioTransactions.create_portfolio_transaction(%{
          "user_id" => user.id,
          "asset_id" => asset.id,
          "action" => "buy",
          "quantity" => "100",
          "price" => "1.00",
          "commission" => "0.00",
          "currency" => "SGD",
          "transaction_date" => ~U[2024-01-01 00:00:00Z]
        })

      {:ok, _} =
        PortfolioTransactions.create_portfolio_transaction(%{
          "user_id" => user.id,
          "asset_id" => asset.id,
          "action" => "buy",
          "quantity" => "50",
          "price" => "1.00",
          "commission" => "0.00",
          "currency" => "SGD",
          "transaction_date" => ~U[2024-01-01 00:00:00Z]
        })

      {:ok, _} =
        Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
          asset.id,
          user.id
        )

      dividend = create_dividend(asset.id)

      assert {:ok, 1} = RealizedProfits.process_dividend_for_all_users(dividend)

      [realized_profit] = RealizedProfits.list_realized_profits_by_asset(asset.id, user.id)

      # 150 shares (100 + 50) * SGD 1.00 dividend = SGD 150.00, not double-counted
      # via the 100-share intermediate position row.
      assert Money.equal?(realized_profit.amount, Money.new(:SGD, "150.00"))
    end
  end

  defp create_sell_transaction(user_id, asset_id) do
    {:ok, buy} =
      PortfolioTransactions.create_portfolio_transaction(%{
        "user_id" => user_id,
        "asset_id" => asset_id,
        "action" => "buy",
        "quantity" => "10",
        "price" => "100.00",
        "commission" => "0.00",
        "currency" => "SGD",
        "transaction_date" => ~U[2024-01-01 00:00:00Z]
      })

    {:ok, sell} =
      PortfolioTransactions.create_portfolio_transaction(%{
        "user_id" => user_id,
        "asset_id" => asset_id,
        "action" => "sell",
        "quantity" => "10",
        "price" => "120.00",
        "commission" => "0.00",
        "currency" => "SGD",
        "transaction_date" => ~U[2024-06-01 00:00:00Z]
      })

    _ = buy
    sell
  end

  defp create_dividend(asset_id) do
    {:ok, dividend} =
      Dividends.create_dividend(%{
        asset_id: asset_id,
        ex_date: ~D[2024-03-01],
        pay_date: ~D[2024-03-15],
        value: Decimal.new("1.00"),
        currency: "SGD"
      })

    dividend
  end
end
