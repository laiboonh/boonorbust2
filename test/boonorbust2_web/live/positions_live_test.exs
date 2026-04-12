defmodule Boonorbust2Web.PositionsLiveTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

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

  describe "index" do
    test "renders positions successfully with empty portfolio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/positions")

      assert html =~ "No portfolio positions yet."
    end

    test "renders enriched positions with data", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Stock",
          price_url: "https://api.marketstack.com/test",
          currency: "USD"
        })

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

      {:ok, _view, html} = live(conn, ~p"/positions")

      assert html =~ "Test Stock"
    end
  end

  describe "filter" do
    test "filters by asset name", %{conn: conn, user: user} do
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

      {:ok, view, _html} = live(conn, ~p"/positions")

      # Filter matching asset name
      html =
        view
        |> form(~s|form[phx-submit="filter"]|, %{"filter" => "Filtered"})
        |> render_submit()

      assert html =~ "Filtered Asset"

      # Filter not matching
      html =
        view
        |> form(~s|form[phx-submit="filter"]|, %{"filter" => "NoMatch"})
        |> render_submit()

      assert html =~ "No positions found matching"
    end

    test "clears filter", %{conn: conn, user: user} do
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

      {:ok, view, _html} = live(conn, ~p"/positions")

      # Apply filter that hides asset
      view
      |> form(~s|form[phx-submit="filter"]|, %{"filter" => "NoMatch"})
      |> render_submit()

      # Clear filter
      html =
        view
        |> element(~s|button[type="button"][phx-click="clear_filter"]|)
        |> render_click()

      assert html =~ "Test Asset"
    end
  end

  describe "positions modal" do
    test "opens and closes position history modal", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Modal Asset",
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

      {:ok, view, _html} = live(conn, ~p"/positions")

      # Open positions modal
      html =
        view
        |> element(~s|button[phx-click="show_positions"][phx-value-id="#{asset.id}"]|)
        |> render_click()

      assert html =~ "Portfolio Positions - Modal Asset"

      # Close positions modal
      html =
        view
        |> element(~s|button[phx-click="close_positions_modal"]|)
        |> render_click()

      refute html =~ "Portfolio Positions - Modal Asset"
    end
  end

  describe "realized profits modal" do
    test "opens and closes realized profits modal", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Profits Asset",
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

      {:ok, view, _html} = live(conn, ~p"/positions")

      # Open realized profits modal
      html =
        view
        |> element(~s|button[phx-click="show_realized_profits"][phx-value-id="#{asset.id}"]|)
        |> render_click()

      assert html =~ "Realized Profits - Profits Asset"

      # Close modal
      html =
        view
        |> element(~s|button[phx-click="close_realized_profits_modal"]|)
        |> render_click()

      refute html =~ "Realized Profits - Profits Asset"
    end
  end

  describe "sorting" do
    test "positions sorted by converted total value descending", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "asset1") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.00}]}}}
        else
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.00}]}}}
        end
      end)

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

      {:ok, _view, html} = live(conn, ~p"/positions")

      # High Value Asset should appear before Low Value Asset
      high_pos = :binary.match(html, "High Value Asset")
      low_pos = :binary.match(html, "Low Value Asset")

      assert high_pos < low_pos
    end
  end
end
