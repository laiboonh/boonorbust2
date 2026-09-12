defmodule Boonorbust2Web.DashboardLiveTest do
  use Boonorbust2Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  setup do
    Cachex.clear(:index_prices_cache)
    :ok
  end

  describe "dashboard live" do
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
      expect_latest_vwra_price(100.0)

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No portfolios yet."

      render_async(view)
    end

    test "renders dashboard with portfolio positions and performs calculations", %{
      conn: conn,
      user: user
    } do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
      end)

      expect_latest_vwra_price(100.0)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/test_asset",
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
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      {:ok, view, html} = live(conn, ~p"/dashboard")

      # Dashboard should render without error
      assert html =~ "Investment Allocation"

      render_async(view)
    end

    test "renders tag chart data", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      expect_latest_vwra_price(100.0)

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

      {:ok, view, html} = live(conn, ~p"/dashboard")

      # Dashboard should render successfully with tag data
      assert html =~ "Investment Allocation"

      render_async(view)
    end

    test "renders investment allocation chart data", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "asset1") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.00}]}}}
        else
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 150.00}]}}}
        end
      end)

      expect_latest_vwra_price(100.0)

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

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Investment Allocation"
      assert html =~ "Percentage of total portfolio value"

      render_async(view)
    end

    test "saves portfolio snapshot when rendering dashboard", %{conn: conn, user: user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.00}]}}}
      end)

      expect_latest_vwra_price(100.0)

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

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      snapshot = Boonorbust2.PortfolioSnapshots.get_latest_snapshot(user.id)
      assert snapshot != nil
      assert snapshot.snapshot_date == Date.utc_today()
      assert Decimal.eq?(snapshot.total_value.amount, Decimal.new(1000))
      assert snapshot.total_value.currency == :USD

      render_async(view)
    end
  end

  describe "dashboard live portfolio IRR" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "irr-test@example.com",
          name: "IRR Test User",
          provider: "google",
          uid: "irrtest123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "renders other dashboard content before the IRR async assign resolves", %{
      conn: conn
    } do
      expect_latest_vwra_price(100.0)

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No portfolios yet."
      assert html =~ "Portfolio IRR"

      render_async(view)
    end

    test "shows the resolved IRR percentage on successful calculation", %{
      conn: conn,
      user: user
    } do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 110.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "IRR Asset",
          price_url: "https://api.marketstack.com/irr_asset",
          currency: "USD"
        })

      transaction_date = DateTime.utc_now() |> DateTime.add(-400, :day)

      {:ok, _transaction} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => transaction_date
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      expect_vwra_price(DateTime.to_date(transaction_date), 90.0)
      expect_latest_vwra_price(110.0)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = render_async(view)

      refute html =~ "IRR unavailable"
      assert html =~ ~r/Portfolio IRR.*?-?\d+(\.\d+)?%/s
    end

    test "shows an explicit unavailable message when calculation returns an error", %{
      conn: conn
    } do
      expect_latest_vwra_price(100.0)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = render_async(view)

      assert html =~ "IRR unavailable"
    end
  end

  describe "dashboard live benchmark IRR" do
    setup do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "benchmark-irr-test@example.com",
          name: "Benchmark IRR Test User",
          provider: "google",
          uid: "benchmarkirrtest123",
          currency: "USD"
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> assign(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "renders other dashboard content before the benchmark IRR async assign resolves", %{
      conn: conn
    } do
      expect_latest_vwra_price(100.0)

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No portfolios yet."
      assert html =~ "vs Global Index (VWRA)"

      render_async(view)
    end

    test "shows the resolved benchmark IRR and delta once both IRR assigns resolve", %{
      conn: conn,
      user: user
    } do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 110.00}]}}}
      end)

      {:ok, asset} =
        Boonorbust2.Assets.create_asset(%{
          name: "Benchmark IRR Asset",
          price_url: "https://api.marketstack.com/benchmark_irr_asset",
          currency: "USD"
        })

      transaction_date = DateTime.utc_now() |> DateTime.add(-400, :day)

      {:ok, _transaction} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.00",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => transaction_date
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      expect_vwra_price(DateTime.to_date(transaction_date), 100.0)
      expect_latest_vwra_price(110.0)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = render_async(view)

      refute html =~ "Benchmark unavailable"
      assert html =~ ~r/vs Global Index \(VWRA\).*?[+-]?\d+(\.\d+)?%.*?VWRA:\s*-?\d+(\.\d+)?%/s
    end

    @tag :capture_log
    test "shows an explicit unavailable message when benchmark calculation returns an error", %{
      conn: conn
    } do
      expect_vwra_price_error()

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = render_async(view)

      assert html =~ "Benchmark unavailable"
    end
  end

  defp expect_vwra_price(date, price) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:ok, %{status: 200, body: vwra_chart_response(date, price)}}
    end)
  end

  defp expect_latest_vwra_price(price) do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:ok, %{status: 200, body: vwra_chart_response(Date.utc_today(), price)}}
    end)
  end

  defp expect_vwra_price_error do
    HTTPClientMock
    |> expect(:get, fn url, _opts ->
      assert url_for_vwra?(url)
      {:error, :network_error}
    end)
  end

  defp url_for_vwra?(url) do
    String.contains?(url, "query1.finance.yahoo.com/v8/finance/chart/VWRA.L")
  end

  defp vwra_chart_response(date, price) do
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
