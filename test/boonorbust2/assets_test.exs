defmodule Boonorbust2.AssetsTest do
  use Boonorbust2.DataCase, async: false

  import Mox

  alias Boonorbust2.Assets
  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  describe "price update rate limiting" do
    test "does not fetch price when asset was updated within 12 hours" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Manually set both inserted_at and updated_at to make them different
      # This simulates an asset that was created earlier and updated 1 hour ago
      old_insert_time =
        DateTime.add(DateTime.utc_now(), -7200, :second) |> DateTime.truncate(:second)

      recent_update_time =
        DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{inserted_at: old_insert_time, updated_at: recent_update_time})
        |> Repo.update!()

      # Mock should not be called for update (rate limited)
      # No expect call means it should not be invoked

      # Update asset with different name (but not price_url)
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Assert the name changed but price was not fetched
      assert updated_asset.name == "Updated Name"
      # Price should still be the original value from creation
      assert Decimal.eq?(updated_asset.price, Decimal.new("50.0"))
    end

    test "fetches price when asset was updated more than 12 hours ago" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Set prices_synced_at to old to trigger price re-fetch
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{prices_synced_at: old_time})
        |> Repo.update!()

      # Reload the asset to get the freshly set timestamps
      asset = Repo.get!(Assets.Asset, asset.id)

      # Mock for update (should be called because asset is stale)
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 123.45}]}}}
      end)

      # Update asset
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Assert the price was updated
      assert Decimal.eq?(updated_asset.price, Decimal.new("123.45"))
    end

    test "fetches price on initial creation when price_url is provided" do
      # Mock for creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 99.99}]}}}
      end)

      # Create asset with price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "New Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Assert the price was fetched
      assert Decimal.eq?(asset.price, Decimal.new("99.99"))
    end

    test "does not fetch price when price_url is nil" do
      # Mock should not be called

      # Create asset without price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Asset Without URL",
          currency: "USD"
        })

      # Price should be nil
      assert asset.price == nil
    end

    test "returns error changeset when price fetch fails on create" do
      # Mock for creation - simulate API failure
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 500}}
      end)

      # Attempt to create asset with price_url
      {:error, changeset} =
        Assets.create_asset(%{
          name: "Failed Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Assert error is on price_url field
      assert %{price_url: ["Failed to fetch price: HTTP request failed with status 500"]} =
               errors_on(changeset)

      # Asset should not be created in database
      assert Assets.get_asset_by_name("Failed Asset") == nil
    end

    test "returns error changeset when price fetch fails on update" do
      # Create asset without price_url first
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          currency: "USD"
        })

      # Mock for update - simulate API failure
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:error, :timeout}
      end)

      # Attempt to update with price_url
      {:error, changeset} =
        Assets.update_asset(asset, %{price_url: "https://api.marketstack.com/price"})

      # Assert error is on price_url field
      assert %{price_url: [_error]} = errors_on(changeset)

      # Asset should not be updated in database
      reloaded_asset = Assets.get_asset!(asset.id)
      assert reloaded_asset.price_url == nil
    end

    test "does not fetch price when updating other fields without changing price_url" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Update only the name, keeping same price_url (within 12 hours)
      # Simulate what the form does - send all fields including unchanged price_url
      # No mock expectation means HTTP client should not be called
      {:ok, updated_asset} =
        Assets.update_asset(asset, %{
          name: "Updated Name",
          price_url: asset.price_url,
          currency: asset.currency
        })

      # Assert only name changed, price unchanged
      assert updated_asset.name == "Updated Name"
      assert Decimal.eq?(updated_asset.price, Decimal.new("50.0"))
    end

    test "validates price_url must be a valid URL" do
      # Attempt to create asset with invalid URL
      {:error, changeset} =
        Assets.create_asset(%{
          name: "Invalid URL Asset",
          price_url: "not-a-url",
          currency: "USD"
        })

      # Assert error is on price_url field
      assert %{price_url: ["must be a valid URL starting with http:// or https://"]} =
               errors_on(changeset)

      # Mock for valid URL test
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.0}]}}}
      end)

      # Valid URLs should work
      {:ok, _asset} =
        Assets.create_asset(%{
          name: "Valid URL Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })
    end

    test "updates updated_at even when fetched price value is unchanged" do
      # Mock for initial creation - price is 50.0
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.marketstack.com/price",
          currency: "USD"
        })

      # Set prices_synced_at to 13+ hours ago to trigger price fetch
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{prices_synced_at: old_time})
        |> Repo.update!()

      # Reload to get the updated prices_synced_at
      asset = Repo.get!(Assets.Asset, asset.id)
      old_prices_synced_at = asset.prices_synced_at

      # Mock for update - API returns SAME price (50.0)
      # This is the key scenario: price value doesn't change
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Update asset (triggers price fetch because > 12 hours old)
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Assert: Price is still 50.0
      assert Decimal.eq?(updated_asset.price, Decimal.new("50.0"))

      # Critical assertion: prices_synced_at MUST be newer even though price didn't change
      # This ensures rate limiting works correctly
      updated_asset_from_db = Repo.get!(Assets.Asset, updated_asset.id)
      assert DateTime.compare(updated_asset_from_db.prices_synced_at, old_prices_synced_at) == :gt

      # Now update again immediately (within 12 hours)
      # Mock should NOT be called because prices_synced_at was properly set above
      # No expect() call means test fails if HTTP client is invoked
      {:ok, final_asset} = Assets.update_asset(updated_asset, %{name: "Final Name"})

      # Price should still be 50.0 (no fetch happened)
      assert Decimal.eq?(final_asset.price, Decimal.new("50.0"))
      assert final_asset.name == "Final Name"
    end

    test "update_all_asset_data respects rate limiting for individual assets" do
      # Create test user
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          uid: "test123",
          currency: "USD"
        })

      # Create 4 assets with price URLs (asset1, asset2, asset3, asset_no_holdings)
      HTTPClientMock
      |> expect(:get, 4, fn _url, _opts ->
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

      {:ok, asset3} =
        Assets.create_asset(%{
          name: "Asset 3",
          price_url: "https://api.marketstack.com/asset3",
          currency: "USD"
        })

      # Create one asset without price_url - should be ignored
      {:ok, _asset_no_url} =
        Assets.create_asset(%{
          name: "Asset No URL",
          currency: "USD"
        })

      # Create asset with price_url but no holdings - should be ignored
      {:ok, asset_no_holdings} =
        Assets.create_asset(%{
          name: "Asset No Holdings",
          price_url: "https://api.marketstack.com/asset_no_holdings",
          currency: "USD"
        })

      # Create positions for assets 1, 2, and 3 so they're eligible for updates
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset1.id,
          "user_id" => user.id,
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
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset3.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      # Calculate positions for the assets with transactions
      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset1.id, user.id)
      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset2.id, user.id)
      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset3.id, user.id)

      # Set asset1 prices_synced_at to old (should be updated)
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset1 =
        asset1
        |> Ecto.Changeset.change(%{prices_synced_at: old_time})
        |> Repo.update!()

      # Set asset2 prices_synced_at to old (should be updated)
      asset2 =
        asset2
        |> Ecto.Changeset.change(%{prices_synced_at: old_time})
        |> Repo.update!()

      # asset3 is recent (within 12 hours) - should NOT be updated
      # Store asset3's current updated_at for later comparison
      _asset3_old_updated_at = Assets.get_asset!(asset3.id).updated_at

      # Mock: Expect only 2 calls (asset1 and asset2), NOT asset3
      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.0}]}}}
      end)

      # Call update_all_asset_data
      {:ok, %{prices_success: prices_success, prices_errors: prices_errors}} =
        Assets.update_all_asset_data()

      # Should have updated 2 assets (asset1 and asset2)
      # asset3 was skipped due to rate limiting
      # asset_no_url was skipped because no price_url
      # asset_no_holdings was skipped because no one holds it
      assert prices_success == 2
      assert prices_errors == 0

      # Verify asset1 and asset2 were updated
      updated_asset1 = Assets.get_asset!(asset1.id)
      updated_asset2 = Assets.get_asset!(asset2.id)
      updated_asset3 = Assets.get_asset!(asset3.id)
      updated_asset_no_holdings = Assets.get_asset!(asset_no_holdings.id)

      assert Decimal.eq?(updated_asset1.price, Decimal.new("200.0"))
      assert Decimal.eq?(updated_asset2.price, Decimal.new("200.0"))

      # asset3 should still have original price (not updated due to rate limiting)
      assert Decimal.eq?(updated_asset3.price, Decimal.new("100.0"))

      # asset_no_holdings should still have original price (no one holds it, so not updated)
      assert Decimal.eq?(updated_asset_no_holdings.price, Decimal.new("100.0"))

      # Verify prices_synced_at was refreshed for updated assets
      assert DateTime.compare(updated_asset1.prices_synced_at, old_time) == :gt
      assert DateTime.compare(updated_asset2.prices_synced_at, old_time) == :gt

      # Verify asset3's price was not updated (rate limited — already checked above)
    end
  end

  describe "list_assets ordering" do
    test "returns assets ordered by most recently updated first" do
      {:ok, asset1} = Assets.create_asset(%{name: "Asset A", currency: "USD"})
      {:ok, asset2} = Assets.create_asset(%{name: "Asset B", currency: "USD"})
      {:ok, asset3} = Assets.create_asset(%{name: "Asset C", currency: "USD"})

      # Set distinct updated_at values
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      asset1
      |> Ecto.Changeset.change(%{updated_at: DateTime.add(now, -3600, :second)})
      |> Repo.update!()

      asset2
      |> Ecto.Changeset.change(%{updated_at: DateTime.add(now, -7200, :second)})
      |> Repo.update!()

      asset3
      |> Ecto.Changeset.change(%{updated_at: now})
      |> Repo.update!()

      assets = Assets.list_assets()
      names = Enum.map(assets, & &1.name)

      assert names == ["Asset C", "Asset A", "Asset B"]
    end

    test "returns assets sorted alphabetically by name when sort: :name is given" do
      {:ok, _} = Assets.create_asset(%{name: "Zebra Fund", currency: "USD"})
      {:ok, _} = Assets.create_asset(%{name: "Apple Stock", currency: "USD"})
      {:ok, _} = Assets.create_asset(%{name: "Mango ETF", currency: "USD"})

      assets = Assets.list_assets(sort: :name)
      names = Enum.map(assets, & &1.name)

      assert names == ["Apple Stock", "Mango ETF", "Zebra Fund"]
    end
  end

  describe "dividend sync rate limiting" do
    test "does not sync dividends when asset was updated within 12 hours" do
      # Mock for initial creation - create asset with dividends already enabled
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped">
           <tbody>
           <tr>
             <td>2024</td>
             <td>5%</td>
             <td>SGD 0.10</td>
             <td>SGD0.05</td>
             <td>2024-01-15</td>
             <td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           <tr>
             <td>SGD0.05</td>
             <td>2024-01-10</td>
             <td>2024-01-25</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody>
           </table>
           </html>
           """
         }}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          currency: "SGD",
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Manually set updated_at to 1 hour ago
      recent_update_time =
        DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{updated_at: recent_update_time})
        |> Repo.update!()

      # Mock should not be called for update (rate limited)
      # No expect call means it should not be invoked

      # Update asset name (not dividend_url) - should NOT trigger dividend sync
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Asset should be updated but dividends not synced due to rate limiting
      assert updated_asset.name == "Updated Name"
      assert updated_asset.distributes_dividends == true
      assert updated_asset.dividend_url == "https://www.dividends.sg/view/test"
    end

    test "syncs dividends when asset was updated more than 12 hours ago" do
      # Create asset without dividends first
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          currency: "SGD",
          distributes_dividends: false
        })

      # Set updated_at to 13+ hours ago
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{updated_at: old_time})
        |> Repo.update!()

      # Mock dividend fetch response
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped">
           <tbody>
           <tr>
             <td>2024</td>
             <td>5%</td>
             <td>SGD 0.05</td>
             <td>SGD0.05</td>
             <td>2024-01-15</td>
             <td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           <tr>
             <td>2023</td>
             <td>4%</td>
             <td>SGD 0.04</td>
             <td>SGD0.04</td>
             <td>2023-07-15</td>
             <td>2023-08-01</td>
             <td>Rate: SGD 0.04</td>
           </tr>
           </tbody>
           </table>
           </html>
           """
         }}
      end)

      # Update asset to enable dividends
      {:ok, updated_asset} =
        Assets.update_asset(asset, %{
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Asset should be updated and dividends synced
      assert updated_asset.distributes_dividends == true
      assert updated_asset.dividend_url == "https://www.dividends.sg/view/test"

      # Verify dividends were stored
      dividends = Boonorbust2.Dividends.list_dividends(asset_id: updated_asset.id)
      assert length(dividends) == 2
    end

    test "syncs dividends on initial creation when dividend_url is provided" do
      # Mock dividend fetch for creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped">
           <tbody>
           <tr>
             <td>2024</td>
             <td>10%</td>
             <td>SGD 0.10</td>
             <td>SGD0.10</td>
             <td>2024-01-15</td>
             <td>2024-02-01</td>
             <td>Rate: SGD 0.10</td>
           </tr>
           </tbody>
           </table>
           </html>
           """
         }}
      end)

      # Create asset with dividend_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Thai Beverage",
          currency: "SGD",
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Verify dividends were synced on creation
      dividends = Boonorbust2.Dividends.list_dividends(asset_id: asset.id)
      assert length(dividends) == 1
      assert Decimal.eq?(hd(dividends).value, Decimal.new("0.10"))
    end

    test "updates updated_at even when no new dividend data is found" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped">
           <tbody>
           <tr>
             <td>2024</td>
             <td>5%</td>
             <td>SGD 0.05</td>
             <td>SGD0.05</td>
             <td>2024-01-15</td>
             <td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody>
           </table>
           </html>
           """
         }}
      end)

      # Create asset with dividend_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          currency: "SGD",
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Set dividends_synced_at to 13+ hours ago to trigger dividend sync
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{dividends_synced_at: old_time})
        |> Repo.update!()

      # Reload to get the updated dividends_synced_at
      asset = Repo.get!(Assets.Asset, asset.id)
      old_dividends_synced_at = asset.dividends_synced_at

      # Mock for update - API returns SAME dividend data
      # This is the key scenario: no new dividends
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped">
           <tbody>
           <tr>
             <td>2024</td>
             <td>5%</td>
             <td>SGD 0.05</td>
             <td>SGD0.05</td>
             <td>2024-01-15</td>
             <td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody>
           </table>
           </html>
           """
         }}
      end)

      # Update asset (triggers dividend sync because dividends_synced_at is old)
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Assert: No new dividends (still just 1)
      dividends = Boonorbust2.Dividends.list_dividends(asset_id: updated_asset.id)
      assert length(dividends) == 1

      # Critical assertion: dividends_synced_at MUST be newer even though no new dividends
      # This ensures rate limiting works correctly
      updated_asset_from_db = Repo.get!(Assets.Asset, updated_asset.id)

      assert DateTime.compare(updated_asset_from_db.dividends_synced_at, old_dividends_synced_at) ==
               :gt

      # Now update again immediately (within 12 hours)
      # Mock should NOT be called because dividends_synced_at was properly set above
      # No expect() call means test fails if HTTP client is invoked
      {:ok, final_asset} = Assets.update_asset(updated_asset, %{name: "Final Name"})

      # Dividends should still be 1 (no sync happened)
      dividends = Boonorbust2.Dividends.list_dividends(asset_id: final_asset.id)
      assert length(dividends) == 1
      assert final_asset.name == "Final Name"
    end

    test "returns error when dividend sync fails on create" do
      # Mock for creation - simulate dividend fetch failure
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 500}}
      end)

      # Attempt to create asset with dividend_url
      {:error, changeset} =
        Assets.create_asset(%{
          name: "Failed Dividend Asset",
          currency: "SGD",
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Assert error is on dividend_url field
      assert %{dividend_url: [error_msg]} = errors_on(changeset)
      assert error_msg =~ "Failed to sync dividends"

      # Asset should not be created in database
      assert Assets.get_asset_by_name("Failed Dividend Asset") == nil
    end

    test "returns error when dividend sync fails on update" do
      # Create asset without dividends first
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          currency: "SGD",
          distributes_dividends: false
        })

      # Set updated_at to old time to force dividend sync
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{updated_at: old_time})
        |> Repo.update!()

      # Mock for update - simulate dividend fetch failure
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:error, :timeout}
      end)

      # Attempt to update with dividend_url
      {:error, changeset} =
        Assets.update_asset(asset, %{
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/test",
          dividend_withholding_tax: Decimal.new("0.30")
        })

      # Assert error is on dividend_url field
      assert %{dividend_url: [error_msg]} = errors_on(changeset)
      assert error_msg =~ "Failed to sync dividends"

      # Asset should not be updated in database
      reloaded_asset = Assets.get_asset!(asset.id)
      assert reloaded_asset.distributes_dividends == false
      assert reloaded_asset.dividend_url == nil
    end
  end

  describe "combined fetch (price_url == dividend_url)" do
    # HTML that dividends.sg would serve — contains both a price and a dividend table.
    @dividends_sg_html """
    <html>
    <div class="dividend-company-quote">
      <strong class="dividend-company-price">1.23</strong>
      <span class="dividend-company-currency">SGD</span>
    </div>
    <table class="table table-bordered table-striped dividend-history-table">
    <tbody>
    <tr>
      <td>2024</td>
      <td>5%</td>
      <td>SGD 0.05</td>
      <td>SGD 0.05</td>
      <td>2024-01-15</td>
      <td>2024-02-01</td>
      <td>Rate: SGD 0.05</td>
    </tr>
    </tbody>
    </table>
    </html>
    """

    # HTML that etnet.com.hk would serve — price in a HeaderTxt span, dividends in a table.
    @etnet_html """
    <html>
    <span class="HeaderTxt up">2.45</span>
    <table>
    <tr><th>Ann Date</th><th>FY</th><th>Particular</th><th>Ex-Date</th><th>BC1</th><th>BC2</th><th>Pay Date</th></tr>
    <tr>
      <td>01/01/2024</td>
      <td>FY2024</td>
      <td>Fin Div HKD 0.1250</td>
      <td>15/01/2024</td>
      <td>20/01/2024</td>
      <td>21/01/2024</td>
      <td>15/02/2024</td>
    </tr>
    </table>
    </html>
    """

    defp old_time,
      do: DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

    defp make_stale(asset) do
      t = old_time()

      asset
      |> Ecto.Changeset.change(%{prices_synced_at: t, dividends_synced_at: t})
      |> Repo.update!()
    end

    test "create_asset makes a single HTTP call for dividends.sg" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @dividends_sg_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "SG Stock",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/test",
          dividend_url: "https://www.dividends.sg/view/test",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      assert Decimal.eq?(asset.price, Decimal.new("1.23"))
      assert asset.prices_synced_at != nil

      dividends = Boonorbust2.Dividends.list_dividends(asset_id: asset.id)
      assert length(dividends) == 1
      assert Decimal.eq?(hd(dividends).value, Decimal.new("0.05"))

      reloaded = Repo.get!(Assets.Asset, asset.id)
      assert reloaded.dividends_synced_at != nil
    end

    test "create_asset makes a single HTTP call for etnet.com.hk" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @etnet_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "HK Stock",
          currency: "HKD",
          price_url: "https://www.etnet.com.hk/www/eng/stocks/realtime/quote.php?code=0001",
          dividend_url: "https://www.etnet.com.hk/www/eng/stocks/realtime/quote.php?code=0001",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      assert Decimal.eq?(asset.price, Decimal.new("2.45"))
      assert asset.prices_synced_at != nil

      dividends = Boonorbust2.Dividends.list_dividends(asset_id: asset.id)
      assert length(dividends) == 1
      assert Decimal.eq?(hd(dividends).value, Decimal.new("0.1250"))

      reloaded = Repo.get!(Assets.Asset, asset.id)
      assert reloaded.dividends_synced_at != nil
    end

    test "create_asset rolls back when combined fetch fails" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:ok, %{status: 500}} end)

      {:error, changeset} =
        Assets.create_asset(%{
          name: "Failed SG Stock",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/test",
          dividend_url: "https://www.dividends.sg/view/test",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      assert %{price_url: [_error]} = errors_on(changeset)
      assert Assets.get_asset_by_name("Failed SG Stock") == nil
    end

    test "update_asset makes a single HTTP call when both timestamps are stale" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @dividends_sg_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "SG Stock",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/test",
          dividend_url: "https://www.dividends.sg/view/test",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      asset = make_stale(asset)

      updated_html = String.replace(@dividends_sg_html, "1.23", "2.50")

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: updated_html}}
      end)

      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated SG Stock"})

      assert Decimal.eq?(updated_asset.price, Decimal.new("2.50"))

      reloaded = Repo.get!(Assets.Asset, updated_asset.id)
      assert DateTime.compare(reloaded.prices_synced_at, old_time()) == :gt
      assert DateTime.compare(reloaded.dividends_synced_at, old_time()) == :gt
    end

    test "update_asset falls back to price-only fetch when only price is stale" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @dividends_sg_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "SG Stock",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/test",
          dividend_url: "https://www.dividends.sg/view/test",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      # Only price is stale; dividends_synced_at stays recent
      asset
      |> Ecto.Changeset.change(%{prices_synced_at: old_time()})
      |> Repo.update!()

      # Exactly ONE HTTP call (price only, not combined)
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: String.replace(@dividends_sg_html, "1.23", "3.00")}}
      end)

      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated"})

      assert Decimal.eq?(updated_asset.price, Decimal.new("3.00"))
    end

    test "create_asset uses separate fetches when price_url and dividend_url differ" do
      # price_url → Marketstack, dividend_url → dividends.sg: must be two HTTP calls
      HTTPClientMock
      |> expect(:get, 1, fn url, _opts ->
        if String.contains?(url, "marketstack") do
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 10.0}]}}}
        else
          {:ok, %{status: 200, body: @dividends_sg_html}}
        end
      end)
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @dividends_sg_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "Mixed URL Stock",
          currency: "SGD",
          price_url: "https://api.marketstack.com/stock",
          dividend_url: "https://www.dividends.sg/view/test",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      assert Decimal.eq?(asset.price, Decimal.new("10.0"))
      assert length(Boonorbust2.Dividends.list_dividends(asset_id: asset.id)) == 1
    end

    test "update_all_asset_data uses combined fetch and counts both price and dividend success" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "combined@example.com",
          name: "Combined User",
          provider: "google",
          uid: "combined123",
          currency: "SGD"
        })

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: @dividends_sg_html}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "SG Combined",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/combined",
          dividend_url: "https://www.dividends.sg/view/combined",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "5",
          "price" => "1.00",
          "currency" => "SGD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)

      make_stale(asset)

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: String.replace(@dividends_sg_html, "1.23", "1.50")}}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_success == 1
      assert result.prices_errors == 0
      assert result.dividends_success == 1
      assert result.dividends_errors == 0

      reloaded = Repo.get!(Assets.Asset, asset.id)
      assert Decimal.eq?(reloaded.price, Decimal.new("1.50"))
    end
  end

  describe "update_all_asset_data result counting" do
    # Shared helper: create a user, buy an asset, calculate a position so
    # the asset has holdings and is eligible for the scheduled job.
    defp setup_asset_with_holdings(asset, user) do
      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => user.id,
          "action" => "buy",
          "quantity" => "5",
          "price" => "10.0",
          "currency" => asset.currency,
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(asset.id, user.id)
    end

    @tag :capture_log
    test "prices_errors incremented when price fetch fails" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_price_err@example.com",
          name: "User",
          provider: "google",
          uid: "uid_price_err",
          currency: "USD"
        })

      # Create asset without triggering an HTTP call on creation (no price_url yet)
      {:ok, asset} = Assets.create_asset(%{name: "Price Fail Asset", currency: "USD"})

      # Add price_url directly so creation didn't fetch
      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/fail",
          prices_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:ok, %{status: 500}} end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_errors == 1
      assert result.prices_success == 0
    end

    @tag :capture_log
    test "dividends_success incremented for non-combined dividend sync" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_div_ok@example.com",
          name: "User",
          provider: "google",
          uid: "uid_div_ok",
          currency: "USD"
        })

      # Create without price_url so price fetch doesn't trigger
      {:ok, asset} = Assets.create_asset(%{name: "Div Only Asset", currency: "USD"})

      # Add a separate dividend_url (Marketstack price, dividends.sg dividends — different URLs)
      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/divonly",
          prices_synced_at: DateTime.utc_now() |> DateTime.truncate(:second),
          dividend_url: "https://www.dividends.sg/view/divonly",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0"),
          dividends_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      # price is fresh (prices_synced_at recent) → no price call
      # dividends are stale (nil) → one dividend call
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped"><tbody>
           <tr>
             <td>2024</td><td>5%</td><td>SGD 0.05</td>
             <td>SGD0.05</td><td>2024-01-15</td><td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody></table>
           </html>
           """
         }}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.dividends_success == 1
      assert result.dividends_errors == 0
      assert result.prices_success == 0
    end

    @tag :capture_log
    test "dividends_errors incremented when dividend sync fails" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_div_err@example.com",
          name: "User",
          provider: "google",
          uid: "uid_div_err",
          currency: "USD"
        })

      {:ok, asset} = Assets.create_asset(%{name: "Div Error Asset", currency: "USD"})

      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/diverr",
          prices_synced_at: DateTime.utc_now() |> DateTime.truncate(:second),
          dividend_url: "https://www.dividends.sg/view/diverr",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0"),
          dividends_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:error, :timeout} end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.dividends_errors == 1
      assert result.dividends_success == 0
      assert result.prices_success == 0
    end

    @tag :capture_log
    test "combined fetch failure increments both prices_errors and dividends_errors" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_combined_err@example.com",
          name: "User",
          provider: "google",
          uid: "uid_combined_err",
          currency: "SGD"
        })

      # Create via direct insert to avoid HTTP call on creation
      asset =
        %Boonorbust2.Assets.Asset{}
        |> Ecto.Changeset.change(%{
          name: "Combined Error Asset",
          currency: "SGD",
          price_url: "https://www.dividends.sg/view/comberr",
          dividend_url: "https://www.dividends.sg/view/comberr",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0"),
          prices_synced_at: nil,
          dividends_synced_at: nil
        })
        |> Repo.insert!()

      setup_asset_with_holdings(asset, user)

      # Both stale + same dividends.sg URL → combined path → fails
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts -> {:ok, %{status: 503}} end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_errors == 1
      assert result.dividends_errors == 1
      assert result.prices_success == 0
      assert result.dividends_success == 0
    end

    @tag :capture_log
    test "only price stale returns {:fetched, :skipped} — prices_success but no dividends_success" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_price_only@example.com",
          name: "User",
          provider: "google",
          uid: "uid_price_only",
          currency: "USD"
        })

      {:ok, asset} = Assets.create_asset(%{name: "Price Only Stale", currency: "USD"})

      # price stale, no dividend_url → dividend skipped
      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/priceonly",
          prices_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 42.0}]}}}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_success == 1
      assert result.prices_errors == 0
      assert result.dividends_success == 0
      assert result.dividends_errors == 0
    end

    @tag :capture_log
    test "only dividends stale returns {:skipped, :synced} — dividends_success but no prices_success" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_div_only@example.com",
          name: "User",
          provider: "google",
          uid: "uid_div_only",
          currency: "USD"
        })

      {:ok, asset} = Assets.create_asset(%{name: "Div Only Stale", currency: "USD"})

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/divonlystale",
          prices_synced_at: now,
          dividend_url: "https://www.dividends.sg/view/divonlystale",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0"),
          dividends_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      # price is fresh → no price call; dividends stale → one call
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped"><tbody>
           <tr>
             <td>2024</td><td>5%</td><td>SGD 0.05</td>
             <td>SGD0.05</td><td>2024-01-15</td><td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody></table>
           </html>
           """
         }}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_success == 0
      assert result.prices_errors == 0
      assert result.dividends_success == 1
      assert result.dividends_errors == 0
    end

    @tag :capture_log
    test "dividends_synced_at updated after successful non-combined dividend sync" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_div_ts@example.com",
          name: "User",
          provider: "google",
          uid: "uid_div_ts",
          currency: "USD"
        })

      {:ok, asset} = Assets.create_asset(%{name: "Div Timestamp Asset", currency: "USD"})

      stale = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/divts",
          prices_synced_at: now,
          dividend_url: "https://www.dividends.sg/view/divts",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0"),
          dividends_synced_at: stale
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html>
           <table class="table-striped"><tbody>
           <tr>
             <td>2024</td><td>5%</td><td>SGD 0.05</td>
             <td>SGD0.05</td><td>2024-01-15</td><td>2024-02-01</td>
             <td>Rate: SGD 0.05</td>
           </tr>
           </tbody></table>
           </html>
           """
         }}
      end)

      {:ok, _result} = Assets.update_all_asset_data()

      reloaded = Repo.get!(Assets.Asset, asset.id)
      assert DateTime.compare(reloaded.dividends_synced_at, stale) == :gt
    end
  end

  describe "update_asset URL change force-fetch" do
    test "changing price_url forces price fetch even when prices_synced_at is fresh" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 10.0}]}}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "URL Change Test",
          price_url: "https://api.marketstack.com/old",
          currency: "USD"
        })

      # prices_synced_at is fresh from creation — normally no refetch
      assert asset.prices_synced_at != nil

      # Changing to a new price_url must force a fetch regardless of freshness
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 99.0}]}}}
      end)

      {:ok, updated} =
        Assets.update_asset(asset, %{price_url: "https://api.marketstack.com/new"})

      assert Decimal.eq?(updated.price, Decimal.new("99.0"))
    end

    test "changing dividend_url forces dividend sync even when dividends_synced_at is fresh" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html><table class="table-striped"><tbody>
           <tr><td>2024</td><td>5%</td><td>SGD 0.05</td>
           <td>SGD0.05</td><td>2024-01-15</td><td>2024-02-01</td>
           <td>Rate: SGD 0.05</td></tr>
           </tbody></table></html>
           """
         }}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "Div URL Change Test",
          currency: "SGD",
          distributes_dividends: true,
          dividend_url: "https://www.dividends.sg/view/old",
          dividend_withholding_tax: Decimal.new("0.0")
        })

      # dividends_synced_at is fresh from creation — normally no re-sync
      reloaded = Repo.get!(Assets.Asset, asset.id)
      assert reloaded.dividends_synced_at != nil

      # Changing dividend_url must force a sync regardless of freshness
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: """
           <html><table class="table-striped"><tbody>
           <tr><td>2024</td><td>8%</td><td>SGD 0.08</td>
           <td>SGD0.08</td><td>2024-06-15</td><td>2024-07-01</td>
           <td>Rate: SGD 0.08</td></tr>
           </tbody></table></html>
           """
         }}
      end)

      {:ok, _updated} =
        Assets.update_asset(reloaded, %{
          dividend_url: "https://www.dividends.sg/view/new",
          distributes_dividends: true,
          dividend_withholding_tax: Decimal.new("0.0")
        })

      dividends = Boonorbust2.Dividends.list_dividends(asset_id: asset.id)
      assert Enum.any?(dividends, fn d -> Decimal.eq?(d.value, Decimal.new("0.08")) end)
    end

    test "string-keyed price_url in attrs triggers force-fetch (form submission style)" do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 10.0}]}}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "String Key Test",
          price_url: "https://api.marketstack.com/old",
          currency: "USD"
        })

      # Use string keys (as Phoenix form params produce) with a new URL
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 55.0}]}}}
      end)

      {:ok, updated} =
        Assets.update_asset(asset, %{
          "price_url" => "https://api.marketstack.com/new",
          "currency" => "USD"
        })

      assert Decimal.eq?(updated.price, Decimal.new("55.0"))
    end
  end

  describe "maybe_sync_and_save_dividends guards" do
    test "skips dividend sync when asset has no dividend_url" do
      # No mock expectation — verifies no HTTP call is made for dividend sync
      {:ok, asset} =
        Assets.create_asset(%{
          name: "No Div URL Asset",
          currency: "USD"
        })

      # Set dividends_synced_at to nil to ensure the rate-limit check would pass
      # if there were a dividend_url — confirms the nil-URL guard fires, not rate limiting
      asset
      |> Ecto.Changeset.change(%{dividends_synced_at: nil})
      |> Repo.update!()

      {:ok, updated} = Assets.update_asset(asset, %{name: "Renamed"})

      assert updated.name == "Renamed"
    end
  end

  describe "update_all_asset_data Alpha Vantage rate limiting" do
    defp create_alpha_vantage_asset(name, user, url_suffix) do
      {:ok, asset} = Assets.create_asset(%{name: name, currency: "USD"})

      asset =
        asset
        |> Ecto.Changeset.change(%{
          price_url: "https://www.alphavantage.co/query?symbol=#{url_suffix}",
          prices_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(asset, user)
      asset
    end

    @tag :capture_log
    test "stops making further Alpha Vantage requests after a rate limit response" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_av_rate_limit@example.com",
          name: "User",
          provider: "google",
          uid: "uid_av_rate_limit",
          currency: "USD"
        })

      create_alpha_vantage_asset("AV Asset 1", user, "one")
      create_alpha_vantage_asset("AV Asset 2", user, "two")

      # Mox fails the test if a second call happens — proving the breaker
      # stopped after the first rate-limited response.
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{
             "Information" => "Thank you for using Alpha Vantage! Rate limit reached."
           }
         }}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_errors == 1
      assert result.prices_success == 0
    end

    @tag :capture_log
    test "a rate-limited Alpha Vantage asset does not affect other sources" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_av_mixed@example.com",
          name: "User",
          provider: "google",
          uid: "uid_av_mixed",
          currency: "USD"
        })

      create_alpha_vantage_asset("AV Mixed Asset", user, "mixed")

      {:ok, other_asset} = Assets.create_asset(%{name: "Marketstack Asset", currency: "USD"})

      other_asset =
        other_asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/mixed",
          prices_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(other_asset, user)

      HTTPClientMock
      |> expect(:get, 2, fn url, _opts ->
        if String.contains?(url, "alphavantage") do
          {:ok, %{status: 200, body: %{"Information" => "Rate limit reached."}}}
        else
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 42.0}]}}}
        end
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_success == 1
      assert result.prices_errors == 1
    end

    @tag :capture_log
    test "processes multiple Alpha Vantage assets sequentially when none are rate limited" do
      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_av_ok@example.com",
          name: "User",
          provider: "google",
          uid: "uid_av_ok",
          currency: "USD"
        })

      create_alpha_vantage_asset("AV OK Asset 1", user, "ok1")
      create_alpha_vantage_asset("AV OK Asset 2", user, "ok2")

      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{"Time Series (Daily)" => %{"2024-01-01" => %{"4. close" => "12.34"}}}
         }}
      end)

      {:ok, result} = Assets.update_all_asset_data()

      assert result.prices_success == 2
      assert result.prices_errors == 0
    end

    test "spaces out consecutive Alpha Vantage requests by the configured interval" do
      Application.put_env(:boonorbust2, :rate_limited_min_interval_ms, 150)
      on_exit(fn -> Application.put_env(:boonorbust2, :rate_limited_min_interval_ms, 0) end)

      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_av_throttle@example.com",
          name: "User",
          provider: "google",
          uid: "uid_av_throttle",
          currency: "USD"
        })

      create_alpha_vantage_asset("AV Throttle Asset 1", user, "throttle1")
      create_alpha_vantage_asset("AV Throttle Asset 2", user, "throttle2")

      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok,
         %{
           status: 200,
           body: %{"Time Series (Daily)" => %{"2024-01-01" => %{"4. close" => "12.34"}}}
         }}
      end)

      start = System.monotonic_time(:millisecond)
      {:ok, result} = Assets.update_all_asset_data()
      elapsed = System.monotonic_time(:millisecond) - start

      assert result.prices_success == 2
      assert elapsed >= 150
    end

    test "runs the non-rate-limited batch concurrently with the rate-limited batch" do
      Application.put_env(:boonorbust2, :rate_limited_min_interval_ms, 100)
      on_exit(fn -> Application.put_env(:boonorbust2, :rate_limited_min_interval_ms, 0) end)

      {:ok, user} =
        Boonorbust2.Accounts.create_user(%{
          email: "user_av_concurrent@example.com",
          name: "User",
          provider: "google",
          uid: "uid_av_concurrent",
          currency: "USD"
        })

      # Three rate-limited assets means two throttle waits of ~100ms each (~200ms total).
      create_alpha_vantage_asset("AV Concurrent Asset 1", user, "concurrent1")
      create_alpha_vantage_asset("AV Concurrent Asset 2", user, "concurrent2")
      create_alpha_vantage_asset("AV Concurrent Asset 3", user, "concurrent3")

      {:ok, other_asset} = Assets.create_asset(%{name: "Marketstack Asset", currency: "USD"})

      other_asset =
        other_asset
        |> Ecto.Changeset.change(%{
          price_url: "https://api.marketstack.com/concurrent",
          prices_synced_at: nil
        })
        |> Repo.update!()

      setup_asset_with_holdings(other_asset, user)

      HTTPClientMock
      |> expect(:get, 4, fn url, _opts ->
        if String.contains?(url, "alphavantage") do
          {:ok,
           %{
             status: 200,
             body: %{"Time Series (Daily)" => %{"2024-01-01" => %{"4. close" => "12.34"}}}
           }}
        else
          Process.sleep(250)
          {:ok, %{status: 200, body: %{"data" => [%{"close" => 42.0}]}}}
        end
      end)

      start = System.monotonic_time(:millisecond)
      {:ok, result} = Assets.update_all_asset_data()
      elapsed = System.monotonic_time(:millisecond) - start

      assert result.prices_success == 4
      # Sequential would be ~250ms (non-rate-limited) + ~200ms (rate-limited throttle) = ~450ms+.
      # Concurrent should be close to max(250ms, 200ms) = ~250ms.
      assert elapsed < 400
    end
  end
end
