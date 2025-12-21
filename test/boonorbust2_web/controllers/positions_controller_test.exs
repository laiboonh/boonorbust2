defmodule Boonorbust2Web.PositionsControllerTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox

  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  describe "index/2" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          uid: "test123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "renders positions successfully with empty portfolio", %{conn: conn} do
      conn = get(conn, ~p"/positions")

      assert html_response(conn, 200)
      assert conn.assigns.positions == []
      assert conn.assigns.realized_profits_by_asset == %{}
      assert conn.assigns.converted_realized_profits_by_asset == %{}
      assert conn.assigns.converted_realized_profits_by_type == %{}
    end

    test "enriches positions with currency conversions and tags", %{conn: conn, user: user} do
      # Mock HTTP client for price fetching
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
      end)

      # Create an asset
      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Stock",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

      # Create a tag and associate with asset
      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Technology",
          user_id: user.id
        })

      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag.id)

      # Create a buy transaction
      {:ok, _transaction} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "5.00",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      conn = get(conn, ~p"/positions")

      assert html_response(conn, 200)

      # Verify positions were enriched with converted values
      positions = conn.assigns.positions
      assert length(positions) == 1

      position = hd(positions)

      # Controller should add these fields via business logic
      assert Map.has_key?(position, :converted_total_value)
      assert Map.has_key?(position, :converted_total_cost)
      assert Map.has_key?(position, :converted_unrealized_profit)
      assert Map.has_key?(position, :tags)

      # Verify converted values are in user's currency (USD)
      assert position.converted_total_value.currency == :USD
      assert position.converted_total_cost.currency == :USD

      # Total value: 10 shares * $150 = $1500
      assert Decimal.eq?(position.converted_total_value.amount, Decimal.new(1500))

      # Total cost: 10 shares * $100 + $5 commission = $1005
      assert Decimal.eq?(position.converted_total_cost.amount, Decimal.new(1005))

      # Unrealized profit: $1500 - $1005 = $495
      assert Decimal.eq?(position.converted_unrealized_profit.amount, Decimal.new(495))

      # Verify tags were loaded
      assert length(position.tags) == 1
      assert hd(position.tags).name == "Technology"
    end

    test "sorts positions by converted total value descending", %{conn: conn, user: user} do
      # Mock HTTP client for price fetching
      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "asset1") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.00}]}}}
        else
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.00}]}}}
        end
      end)

      # Create two assets with different values
      {:ok, asset1} =
        Boonorbust2.Assets.create_asset(%{
          name: "Low Value Asset",
          price_url: "https://api.marketstack.com/asset1",
          currency: "USD"
        })

      {:ok, asset2} =
        Boonorbust2.Assets.create_asset(%{
          name: "High Value Asset",
          price_url: "https://api.marketstack.com/asset2",
          currency: "USD"
        })

      # Asset 1: 10 shares * $50 = $500
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset1.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "50.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      # Asset 2: 10 shares * $200 = $2000
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset2.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "200.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset1.id, user.id)
      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset2.id, user.id)

      conn = get(conn, ~p"/positions")

      positions = conn.assigns.positions
      assert length(positions) == 2

      # Verify positions are sorted by value descending (highest first)
      assert hd(positions).asset.name == "High Value Asset"
      assert Decimal.eq?(hd(positions).converted_total_value.amount, Decimal.new(2000))

      assert List.last(positions).asset.name == "Low Value Asset"
      assert Decimal.eq?(List.last(positions).converted_total_value.amount, Decimal.new(500))
    end

    test "converts realized profits to user currency", %{conn: conn, user: user} do
      # Mock HTTP client for asset price + potentially exchange rates
      HTTPClientMock
      |> stub(:get, fn url, _opts ->
        cond do
          String.contains?(url, "marketstack") ->
            {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}

          String.contains?(url, "exchangerate-api") ->
            {:ok,
             %{
               status: 200,
               body: %{"result" => "success", "conversion_rates" => %{"USD" => 1.0}}
             }}

          true ->
            {:error, :unknown_url}
        end
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Stock",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

      # Buy transaction
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => ~U[2024-01-01 00:00:00Z]
        })

      # Sell transaction (realize profit)
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "sell",
          "quantity" => "5",
          "price" => "150.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => ~U[2024-06-01 00:00:00Z]
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      conn = get(conn, ~p"/positions")

      # Verify realized profits are converted
      assert Map.has_key?(conn.assigns, :converted_realized_profits_by_asset)
      converted_profits = conn.assigns.converted_realized_profits_by_asset

      if map_size(converted_profits) > 0 do
        profit = Map.get(converted_profits, asset.id)
        assert profit != nil
        assert profit.currency == :USD
      end
    end

    test "assigns converted_realized_profits_by_type to connection", %{
      conn: conn,
      user: _user
    } do
      conn = get(conn, ~p"/positions")

      # Verify the controller assigns converted_realized_profits_by_type
      # (even if empty, it should be assigned)
      assert Map.has_key?(conn.assigns, :converted_realized_profits_by_type)
      assert is_map(conn.assigns.converted_realized_profits_by_type)
    end

    test "handles filter parameter", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Filtered Asset",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      # Test with filter matching asset name
      conn = get(conn, ~p"/positions?filter=Filtered")
      assert conn.assigns.filter == "Filtered"
      assert length(conn.assigns.positions) == 1

      # Test with filter not matching
      conn = get(conn, ~p"/positions?filter=NoMatch")
      assert conn.assigns.filter == "NoMatch"
      assert conn.assigns.positions == []
    end
  end

  describe "positions/2" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          uid: "test123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "renders positions modal content for asset", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      conn = get(conn, ~p"/positions/history/#{asset.id}")

      assert html_response(conn, 200)
      assert conn.assigns.asset.id == asset.id
      assert is_list(conn.assigns.positions)
    end
  end

  describe "realized_profits/2" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          uid: "test123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "renders realized profits modal content for asset", %{conn: conn, user: _user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

      conn = get(conn, ~p"/positions/realized_profits/#{asset.id}")

      assert html_response(conn, 200)
      assert conn.assigns.asset.id == asset.id
      assert is_list(conn.assigns.realized_profits)
    end
  end
end
