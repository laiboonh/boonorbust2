defmodule Boonorbust2.PortfolioPositionsTest do
  use Boonorbust2.DataCase, async: true

  alias Boonorbust2.Accounts
  alias Boonorbust2.Assets
  alias Boonorbust2.PortfolioPositions
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

    %{user: user}
  end

  describe "calculate_and_upsert_positions_for_asset/2" do
    test "returns {:ok, 0} when asset has no transactions", %{user: user} do
      asset = create_asset("AAPL", "Apple Inc.")

      assert {:ok, 0} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      assert [] = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
    end

    test "creates single position for single buy transaction", %{user: user} do
      asset = create_asset("AAPL", "Apple Inc.")

      transaction =
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "100",
          price_amount: "150.00",
          commission_amount: "10.00",
          transaction_date: ~U[2024-01-01 00:00:00Z]
        })

      assert {:ok, 1} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 1

      [position] = positions
      assert position.asset_id == asset.id
      assert position.portfolio_transaction_id == transaction.id
      assert Decimal.equal?(position.quantity_on_hand, Decimal.new("100"))
      # Average price = (150 * 100 + 10) / 100 = 150.10
      assert Money.equal?(position.average_price, Money.new(:SGD, "150.10"))
      # Amount on hand = 150.10 * 100 = 15010.00
      assert Money.equal?(position.amount_on_hand, Money.new(:SGD, "15010.00"))
    end

    test "creates multiple positions for multiple buy transactions", %{user: user} do
      asset = create_asset("AAPL", "Apple Inc.")

      txn1 =
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "100",
          price_amount: "150.00",
          commission_amount: "10.00",
          transaction_date: ~U[2024-01-01 00:00:00Z]
        })

      txn2 =
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "50",
          price_amount: "160.00",
          commission_amount: "5.00",
          transaction_date: ~U[2024-01-15 00:00:00Z]
        })

      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 2

      [pos2, pos1] = positions

      # First position: 100 shares at average of 150.10
      assert pos1.portfolio_transaction_id == txn1.id
      assert Decimal.equal?(pos1.quantity_on_hand, Decimal.new("100"))
      assert Money.equal?(pos1.average_price, Money.new(:SGD, "150.10"))
      assert Money.equal?(pos1.amount_on_hand, Money.new(:SGD, "15010.00"))

      # Second position: 150 shares total
      # Average price = (150.10 * 100 + 8005) / 150 = 153.4333 (rounded to 4 decimals)
      assert pos2.portfolio_transaction_id == txn2.id
      assert Decimal.equal?(pos2.quantity_on_hand, Decimal.new("150"))
      assert Money.equal?(pos2.average_price, Money.new(:SGD, "153.4333"))
      # Amount on hand = 153.4333 * 150 = 23014.995 (rounded to 23015.0000)
      assert Money.equal?(pos2.amount_on_hand, Money.new(:SGD, "23015.0000"))
    end

    test "creates position for buy then sell transaction (average price unchanged on sell)", %{
      user: user
    } do
      asset = create_asset("AAPL", "Apple Inc.")

      txn1 =
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "100",
          price_amount: "150.00",
          commission_amount: "10.00",
          transaction_date: ~U[2024-01-01 00:00:00Z]
        })

      txn2 =
        create_transaction(user.id, asset.id, %{
          action: "sell",
          quantity: "30",
          price_amount: "160.00",
          commission_amount: "5.00",
          transaction_date: ~U[2024-01-15 00:00:00Z]
        })

      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 2

      [pos2, pos1] = positions

      # First position: 100 shares
      assert pos1.portfolio_transaction_id == txn1.id
      assert Decimal.equal?(pos1.quantity_on_hand, Decimal.new("100"))
      assert Money.equal?(pos1.average_price, Money.new(:SGD, "150.10"))
      assert Money.equal?(pos1.amount_on_hand, Money.new(:SGD, "15010.00"))

      # Second position after sell: 70 shares remaining, same average price
      assert pos2.portfolio_transaction_id == txn2.id
      assert Decimal.equal?(pos2.quantity_on_hand, Decimal.new("70"))
      assert Money.equal?(pos2.average_price, Money.new(:SGD, "150.10"))
      # Amount on hand = 150.10 * 70 = 10507.00
      assert Money.equal?(pos2.amount_on_hand, Money.new(:SGD, "10507.00"))

      # Verify realized profit for sell transaction
      # Realized profit = (sell_price - avg_cost_price) * quantity
      # = (160.00 - 150.10) * 30 = 9.90 * 30 = 297.00
      realized_profit = RealizedProfits.get_realized_profit_by_transaction(txn2.id)
      assert realized_profit != nil
      assert realized_profit.user_id == user.id
      assert realized_profit.asset_id == asset.id
      assert realized_profit.portfolio_transaction_id == txn2.id
      assert Money.equal?(realized_profit.amount, Money.new(:SGD, "297.00"))
    end

    test "handles multiple buys and sells maintaining correct average price", %{user: user} do
      asset = create_asset("TSLA", "Tesla Inc.")

      # Buy 100 @ 200
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "100",
        price_amount: "200.00",
        commission_amount: "10.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      # Buy 50 @ 220
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "220.00",
        commission_amount: "5.00",
        transaction_date: ~U[2024-02-01 00:00:00Z]
      })

      # Sell 60
      txn3 =
        create_transaction(user.id, asset.id, %{
          action: "sell",
          quantity: "60",
          price_amount: "250.00",
          commission_amount: "8.00",
          transaction_date: ~U[2024-03-01 00:00:00Z]
        })

      # Buy 40 @ 180
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "40",
        price_amount: "180.00",
        commission_amount: "6.00",
        transaction_date: ~U[2024-04-01 00:00:00Z]
      })

      assert {:ok, 4} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 4

      [pos4, pos3, pos2, pos1] = positions

      # Position 1: 100 shares @ avg 200.10
      assert Decimal.equal?(pos1.quantity_on_hand, Decimal.new("100"))
      assert Money.equal?(pos1.average_price, Money.new(:SGD, "200.10"))

      # Position 2: 150 shares @ avg 206.7667
      # (200.10 * 100 + 11005) / 150 = 206.7667
      assert Decimal.equal?(pos2.quantity_on_hand, Decimal.new("150"))
      assert Money.equal?(pos2.average_price, Money.new(:SGD, "206.7667"))

      # Position 3: 90 shares @ avg 206.7667 (unchanged after sell)
      assert Decimal.equal?(pos3.quantity_on_hand, Decimal.new("90"))
      assert Money.equal?(pos3.average_price, Money.new(:SGD, "206.7667"))

      # Position 4: 130 shares @ new avg
      # (206.7667 * 90 + 7206) / 130 = 198.5769
      assert Decimal.equal?(pos4.quantity_on_hand, Decimal.new("130"))
      assert Money.equal?(pos4.average_price, Money.new(:SGD, "198.5769"))

      # Verify realized profit for sell transaction
      # Realized profit = (sell_price - avg_cost_price) * quantity
      # = (250.00 - 206.7667) * 60 = 43.2333 * 60 = 2593.998 (rounded to 2594.0000)
      realized_profit = RealizedProfits.get_realized_profit_by_transaction(txn3.id)
      assert realized_profit != nil
      assert realized_profit.user_id == user.id
      assert realized_profit.asset_id == asset.id
      assert realized_profit.portfolio_transaction_id == txn3.id
      assert Money.equal?(realized_profit.amount, Money.new(:SGD, "2594.0000"))
    end

    test "handles sell reducing position to zero", %{user: user} do
      asset = create_asset("NVDA", "NVIDIA Corp.")

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "500.00",
        commission_amount: "15.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      txn2 =
        create_transaction(user.id, asset.id, %{
          action: "sell",
          quantity: "50",
          price_amount: "600.00",
          commission_amount: "20.00",
          transaction_date: ~U[2024-06-01 00:00:00Z]
        })

      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 2

      [pos2, _pos1] = positions

      # Final position: 0 shares remaining
      assert Decimal.equal?(pos2.quantity_on_hand, Decimal.new("0"))
      # Average price should still be maintained
      assert Money.equal?(pos2.average_price, Money.new(:SGD, "500.30"))

      # Verify realized profit for sell transaction
      # Realized profit = (sell_price - avg_cost_price) * quantity
      # = (600.00 - 500.30) * 50 = 99.70 * 50 = 4985.00
      realized_profit = RealizedProfits.get_realized_profit_by_transaction(txn2.id)
      assert realized_profit != nil
      assert realized_profit.user_id == user.id
      assert realized_profit.asset_id == asset.id
      assert realized_profit.portfolio_transaction_id == txn2.id
      assert Money.equal?(realized_profit.amount, Money.new(:SGD, "4985.00"))
    end

    test "handles position going to zero then buying again (resets average price)", %{
      user: user
    } do
      asset = create_asset("MSFT", "Microsoft Corp.")

      # Buy 100
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "100",
        price_amount: "300.00",
        commission_amount: "10.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      # Sell all 100
      txn2 =
        create_transaction(user.id, asset.id, %{
          action: "sell",
          quantity: "100",
          price_amount: "350.00",
          commission_amount: "12.00",
          transaction_date: ~U[2024-03-01 00:00:00Z]
        })

      # Buy 80 again (should reset average price)
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "80",
        price_amount: "320.00",
        commission_amount: "8.00",
        transaction_date: ~U[2024-06-01 00:00:00Z]
      })

      assert {:ok, 3} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 3

      [pos3, pos2, pos1] = positions

      # Position 1: 100 @ 300.10
      assert Decimal.equal?(pos1.quantity_on_hand, Decimal.new("100"))
      assert Money.equal?(pos1.average_price, Money.new(:SGD, "300.10"))

      # Position 2: 0 shares
      assert Decimal.equal?(pos2.quantity_on_hand, Decimal.new("0"))

      # Position 3: 80 shares @ fresh average 320.10
      assert Decimal.equal?(pos3.quantity_on_hand, Decimal.new("80"))
      assert Money.equal?(pos3.average_price, Money.new(:SGD, "320.10"))

      # Verify realized profit for sell transaction
      # Realized profit = (sell_price - avg_cost_price) * quantity
      # = (350.00 - 300.10) * 100 = 49.90 * 100 = 4990.00
      realized_profit = RealizedProfits.get_realized_profit_by_transaction(txn2.id)
      assert realized_profit != nil
      assert realized_profit.user_id == user.id
      assert realized_profit.asset_id == asset.id
      assert realized_profit.portfolio_transaction_id == txn2.id
      assert Money.equal?(realized_profit.amount, Money.new(:SGD, "4990.00"))
    end

    test "raises exception when mixing different currencies for same asset", %{user: user} do
      asset = create_asset("GOOGL", "Alphabet Inc.")

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "100",
        price_amount: "100.00",
        commission_amount: "5.00",
        currency: "USD",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      # Second transaction with different currency - this should cause an error
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "110.00",
        commission_amount: "3.00",
        currency: "SGD",
        transaction_date: ~U[2024-02-01 00:00:00Z]
      })

      # Money.add will return error when trying to add USD and SGD
      # causing a MatchError in the pattern match
      assert_raise MatchError, fn ->
        PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)
      end
    end

    test "function is idempotent - calling multiple times produces same results", %{user: user} do
      asset = create_asset("META", "Meta Platforms")

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "100",
        price_amount: "300.00",
        commission_amount: "10.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "320.00",
        commission_amount: "5.00",
        transaction_date: ~U[2024-02-01 00:00:00Z]
      })

      # First calculation
      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions_first = PortfolioPositions.get_positions_for_asset(asset.id, user.id)

      # Second calculation (idempotent - should update existing records)
      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions_second = PortfolioPositions.get_positions_for_asset(asset.id, user.id)

      assert length(positions_first) == 2
      assert length(positions_second) == 2

      # Verify IDs are the same (not creating new records)
      ids_first = Enum.map(positions_first, & &1.id) |> Enum.sort()
      ids_second = Enum.map(positions_second, & &1.id) |> Enum.sort()
      assert ids_first == ids_second

      # Verify values remain the same
      for {pos1, pos2} <- Enum.zip(positions_first, positions_second) do
        assert pos1.id == pos2.id
        assert pos1.asset_id == pos2.asset_id
        assert pos1.portfolio_transaction_id == pos2.portfolio_transaction_id
        assert Decimal.equal?(pos1.quantity_on_hand, pos2.quantity_on_hand)
        assert Money.equal?(pos1.average_price, pos2.average_price)
        assert DateTime.compare(pos1.inserted_at, pos2.inserted_at) == :eq
      end
    end

    test "updates existing positions when recalculating", %{user: user} do
      asset = create_asset("AMD", "AMD Inc.")

      txn1 =
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "100",
          price_amount: "80.00",
          commission_amount: "5.00",
          transaction_date: ~U[2024-01-01 00:00:00Z]
        })

      # First calculation
      assert {:ok, 1} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions_before = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions_before) == 1

      # Add another transaction
      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "90.00",
        commission_amount: "3.00",
        transaction_date: ~U[2024-02-01 00:00:00Z]
      })

      # Recalculate - should update existing position and add new one
      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions_after = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions_after) == 2

      # First position should still have same transaction ID
      [_pos2, pos1] = positions_after
      assert pos1.portfolio_transaction_id == txn1.id
    end

    test "raises exception when selling without prior buy transaction", %{user: user} do
      asset = create_asset("INTC", "Intel Corp.")

      create_transaction(user.id, asset.id, %{
        action: "sell",
        quantity: "50",
        price_amount: "40.00",
        commission_amount: "2.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      assert_raise ArgumentError, ~r/Cannot sell asset without a prior buy transaction/, fn ->
        PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)
      end
    end

    test "handles many transactions efficiently", %{user: user} do
      asset = create_asset("SPY", "S&P 500 ETF")

      # Create 20 buy transactions
      for i <- 1..20 do
        create_transaction(user.id, asset.id, %{
          action: "buy",
          quantity: "10",
          price_amount: "#{400 + i}.00",
          commission_amount: "1.00",
          transaction_date: DateTime.add(~U[2024-01-01 00:00:00Z], i, :day)
        })
      end

      assert {:ok, 20} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      positions = PortfolioPositions.get_positions_for_asset(asset.id, user.id)
      assert length(positions) == 20

      # Final position should have 200 shares (10 * 20)
      final_position = List.first(positions)
      assert Decimal.equal?(final_position.quantity_on_hand, Decimal.new("200"))
    end

    test "get_latest_position_for_asset returns most recent position", %{user: user} do
      asset = create_asset("BTC", "Bitcoin")

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "1",
        price_amount: "50000.00",
        commission_amount: "50.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      create_transaction(user.id, asset.id, %{
        action: "buy",
        quantity: "0.5",
        price_amount: "55000.00",
        commission_amount: "30.00",
        transaction_date: ~U[2024-02-01 00:00:00Z]
      })

      assert {:ok, 2} =
               PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      latest_position = PortfolioPositions.get_latest_position_for_asset(asset.id, user.id)
      assert latest_position != nil
      assert Decimal.equal?(latest_position.quantity_on_hand, Decimal.new("1.5"))
    end

    test "list_latest_positions returns one position per asset", %{user: user} do
      asset1 = create_asset("AAPL", "Apple Inc.")
      asset2 = create_asset("MSFT", "Microsoft Corp.")

      # Create transactions for both assets
      create_transaction(user.id, asset1.id, %{
        action: "buy",
        quantity: "100",
        price_amount: "150.00",
        commission_amount: "10.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      create_transaction(user.id, asset2.id, %{
        action: "buy",
        quantity: "50",
        price_amount: "300.00",
        commission_amount: "8.00",
        transaction_date: ~U[2024-01-01 00:00:00Z]
      })

      PortfolioPositions.calculate_and_upsert_positions_for_asset(asset1.id, user.id)
      PortfolioPositions.calculate_and_upsert_positions_for_asset(asset2.id, user.id)

      latest_positions = PortfolioPositions.list_latest_positions(user.id)
      assert length(latest_positions) == 2

      asset_ids = Enum.map(latest_positions, & &1.asset_id) |> Enum.sort()
      assert asset_ids == Enum.sort([asset1.id, asset2.id])
    end
  end

  # Helper functions

  defp create_asset(code, name) do
    {:ok, asset} =
      Assets.create_asset(%{
        code: code,
        name: name,
        currency: "SGD"
      })

    asset
  end

  defp create_transaction(user_id, asset_id, attrs) do
    currency = Map.get(attrs, :currency, "SGD")

    # Create transaction params in the same format as the web controller
    # (string keys, string/decimal values, separate currency field)
    transaction_attrs = %{
      "user_id" => user_id,
      "asset_id" => asset_id,
      "action" => attrs.action,
      "quantity" => attrs.quantity,
      "price" => attrs.price_amount,
      "commission" => attrs.commission_amount,
      "currency" => currency,
      "transaction_date" => attrs.transaction_date
    }

    {:ok, transaction} = PortfolioTransactions.create_portfolio_transaction(transaction_attrs)
    transaction
  end
end
