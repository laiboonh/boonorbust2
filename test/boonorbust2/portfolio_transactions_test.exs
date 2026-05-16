defmodule Boonorbust2.PortfolioTransactionsTest do
  use Boonorbust2.DataCase, async: false

  alias Boonorbust2.PortfolioTransactions

  setup do
    {:ok, user} =
      Boonorbust2.Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        provider: "google",
        uid: "test123",
        currency: "USD"
      })

    {:ok, asset} =
      Boonorbust2.Assets.create_asset(%{
        name: "AAPL",
        currency: "USD"
      })

    {:ok, user: user, asset: asset}
  end

  describe "create_portfolio_transaction/1 — amount calculation" do
    test "buy: amount = (quantity × price) + commission", %{user: user, asset: asset} do
      attrs = %{
        "user_id" => user.id,
        "asset_id" => asset.id,
        "action" => "buy",
        "quantity" => "10",
        "price" => "100.00",
        "commission" => "5.00",
        "currency" => "USD",
        "transaction_date" => "2024-01-15T10:00:00Z"
      }

      {:ok, transaction} = PortfolioTransactions.create_portfolio_transaction(attrs)

      # 10 × 100 + 5 = 1005
      assert transaction.amount == Money.new(:USD, "1005.00")
    end

    test "sell: amount = (quantity × price) − commission", %{user: user, asset: asset} do
      # First buy so we have holdings to sell
      {:ok, _} =
        PortfolioTransactions.create_portfolio_transaction(%{
          "user_id" => user.id,
          "asset_id" => asset.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "commission" => "5.00",
          "currency" => "USD",
          "transaction_date" => "2024-01-15T10:00:00Z"
        })

      attrs = %{
        "user_id" => user.id,
        "asset_id" => asset.id,
        "action" => "sell",
        "quantity" => "5",
        "price" => "120.00",
        "commission" => "5.00",
        "currency" => "USD",
        "transaction_date" => "2024-02-01T10:00:00Z"
      }

      {:ok, transaction} = PortfolioTransactions.create_portfolio_transaction(attrs)

      # 5 × 120 − 5 = 595
      assert transaction.amount == Money.new(:USD, "595.00")
    end
  end
end
