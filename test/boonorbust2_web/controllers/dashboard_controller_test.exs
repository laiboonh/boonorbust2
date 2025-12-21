defmodule Boonorbust2Web.DashboardControllerTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox

  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  describe "index/2 - business logic that should move to context" do
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

    test "renders dashboard successfully with empty portfolio", %{conn: conn} do
      # Test that dashboard renders even with no positions
      conn = get(conn, ~p"/dashboard")

      assert html_response(conn, 200)
      assert conn.assigns.positions == []
    end

    test "renders dashboard with portfolio positions and performs calculations", %{
      conn: conn,
      user: user
    } do
      # Create an asset
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/test_asset",
          currency: "USD"
        })

      # Create a transaction
      {:ok, _transaction} =
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

      # Get dashboard
      conn = get(conn, ~p"/dashboard")

      assert html_response(conn, 200)

      # Verify the controller performed currency conversion calculations
      positions = conn.assigns.positions
      assert length(positions) == 1

      position = hd(positions)
      # Controller should have added converted values
      assert Map.has_key?(position, :converted_total_value)
      assert Map.has_key?(position, :converted_total_cost)
      assert Map.has_key?(position, :converted_unrealized_profit)

      # Verify values are in USD (same as user currency)
      assert position.converted_total_value.currency == :USD
      # Total value should be 10 shares * 150 price = 1500
      assert Decimal.eq?(position.converted_total_value.amount, Decimal.new(1500))
    end

    test "assigns tag chart data to connection", %{conn: conn, user: user} do
      # Create asset with tag
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Tech Asset",
          price_url: "https://api.marketstack.com/tech",
          currency: "USD"
        })

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Technology",
          user_id: user.id
        })

      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag.id)

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

      conn = get(conn, ~p"/dashboard")

      # Verify tag chart data was calculated and assigned
      assert Map.has_key?(conn.assigns, :tag_chart_data)
      tag_chart_data = conn.assigns.tag_chart_data
      assert is_list(tag_chart_data)
      assert length(tag_chart_data) > 0

      # Should contain Technology tag with aggregated value
      tech_data = Enum.find(tag_chart_data, &(&1.label == "Technology"))
      assert tech_data != nil
      assert tech_data.value == 1000.0
    end

    test "assigns investment allocation chart data to connection", %{conn: conn, user: user} do
      # Create two assets with different values
      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "asset1") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.00}]}}}
        else
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
        end
      end)

      {:ok, asset1} =
        Boonorbust2.Assets.create_asset(%{
          name: "Asset 1",
          price_url: "https://api.marketstack.com/asset1",
          currency: "USD"
        })

      {:ok, asset2} =
        Boonorbust2.Assets.create_asset(%{
          name: "Asset 2",
          price_url: "https://api.marketstack.com/asset2",
          currency: "USD"
        })

      # Asset 1: 10 shares * 50 = 500 (25% of total)
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset1.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      # Asset 2: 10 shares * 150 = 1500 (75% of total)
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset2.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset1.id, user.id)
      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset2.id, user.id)

      conn = get(conn, ~p"/dashboard")

      # Verify investment allocation data was calculated
      assert Map.has_key?(conn.assigns, :investment_allocation_chart_data)
      allocation_data = conn.assigns.investment_allocation_chart_data
      assert is_list(allocation_data)
      assert length(allocation_data) == 2

      # Verify percentages are calculated correctly
      # Total: 500 + 1500 = 2000
      asset1_data = Enum.find(allocation_data, &(&1.label == "Asset 1"))
      asset2_data = Enum.find(allocation_data, &(&1.label == "Asset 2"))

      assert asset1_data.percentage == 25.0
      assert asset2_data.percentage == 75.0
    end

    test "saves portfolio snapshot when rendering dashboard", %{conn: conn, user: user} do
      # Create asset with position
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

      # Render dashboard (this should create a snapshot)
      get(conn, ~p"/dashboard")

      # Verify snapshot was created
      snapshot = Boonorbust2.PortfolioSnapshots.get_latest_snapshot(user.id)
      assert snapshot != nil
      assert snapshot.snapshot_date == Date.utc_today()
      assert Decimal.eq?(snapshot.total_value.amount, Decimal.new(1000))
      assert snapshot.total_value.currency == :USD
    end
  end
end
