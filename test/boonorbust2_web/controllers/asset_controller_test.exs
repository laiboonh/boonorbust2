defmodule Boonorbust2Web.AssetControllerTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox
  import Phoenix.ConnTest

  alias Boonorbust2.Assets
  alias Boonorbust2.HTTPClientMock
  alias Boonorbust2.Repo

  setup :verify_on_exit!

  describe "update_all_prices/2" do
    setup do
      # Set admin email in application config
      Application.put_env(:boonorbust2, :admins, ["admin@example.com"])

      # Create admin user
      {:ok, admin_user} =
        Boonorbust2.Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin User",
          provider: "google",
          uid: "admin123",
          currency: "USD"
        })

      # Create regular user for holdings
      {:ok, regular_user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user@example.com",
          name: "Regular User",
          provider: "google",
          uid: "user123",
          currency: "USD"
        })

      # Log in as admin
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: admin_user.id})
        |> assign(:current_user, admin_user)
        |> fetch_flash()

      {:ok, conn: conn, admin_user: admin_user, regular_user: regular_user}
    end

    test "formats success message when all updates succeed", %{
      conn: conn,
      regular_user: regular_user
    } do
      # Create assets with price URLs
      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.0}]}}}
      end)

      {:ok, asset1} =
        Assets.create_asset(%{
          name: "Asset 1",
          price_url: "https://api.marketstack.com/asset1",
          currency: "USD"
        })

      {:ok, asset2} =
        Assets.create_asset(%{
          name: "Asset 2",
          price_url: "https://api.marketstack.com/asset2",
          currency: "USD"
        })

      # Create holdings
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset1.id,
          "user_id" => regular_user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset2.id,
          "user_id" => regular_user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
        asset1.id,
        regular_user.id
      )

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
        asset2.id,
        regular_user.id
      )

      # Make assets old so they get updated
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset1
      |> Ecto.Changeset.change(%{updated_at: old_time})
      |> Repo.update!()

      asset2
      |> Ecto.Changeset.change(%{updated_at: old_time})
      |> Repo.update!()

      # Mock price updates
      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.0}]}}}
      end)

      # Call update_all_prices
      conn = post(conn, ~p"/assets/update_all_prices")

      # Assert response contains success message with no errors
      assert response(conn, 200) =~ "Successfully updated 2 prices and 0 dividends"
    end

    @tag :capture_log
    test "formats message with error count when some updates fail", %{
      conn: conn,
      regular_user: regular_user
    } do
      # Create one asset that will succeed and one that will fail
      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.0}]}}}
      end)

      {:ok, asset1} =
        Assets.create_asset(%{
          name: "Asset 1",
          price_url: "https://api.marketstack.com/asset1",
          currency: "USD"
        })

      {:ok, asset2} =
        Assets.create_asset(%{
          name: "Asset 2",
          price_url: "https://api.marketstack.com/asset2",
          currency: "USD"
        })

      # Create holdings
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset1.id,
          "user_id" => regular_user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset2.id,
          "user_id" => regular_user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
        asset1.id,
        regular_user.id
      )

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
        asset2.id,
        regular_user.id
      )

      # Make assets old
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset1
      |> Ecto.Changeset.change(%{updated_at: old_time})
      |> Repo.update!()

      asset2
      |> Ecto.Changeset.change(%{updated_at: old_time})
      |> Repo.update!()

      # Mock: one success, one failure
      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "asset1") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.0}]}}}
        else
          {:ok, %{status: 500}}
        end
      end)

      # Call update_all_prices
      conn = post(conn, ~p"/assets/update_all_prices")

      # Assert response contains message with error count
      response_text = response(conn, 200)
      assert response_text =~ "1 prices"
      assert response_text =~ "0 dividends"
      assert response_text =~ "1 error"
    end

    test "requires admin authentication", %{regular_user: regular_user} do
      # Log in as regular user
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: regular_user.id})
        |> assign(:current_user, regular_user)
        |> fetch_flash()

      # Attempt to call update_all_prices should fail
      conn = post(conn, ~p"/assets/update_all_prices")

      # Should redirect or return unauthorized
      assert conn.status in [302, 403]
    end
  end
end
