defmodule Boonorbust2.AssetsTest do
  use Boonorbust2.DataCase, async: false

  import Mox

  alias Boonorbust2.Assets
  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  describe "price update rate limiting" do
    test "does not fetch price when asset was updated within 24 hours" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.example.com/price",
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

    test "fetches price when asset was updated more than 24 hours ago" do
      # Mock for initial creation
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Create asset with a price_url
      {:ok, asset} =
        Assets.create_asset(%{
          name: "Test Asset",
          price_url: "https://api.example.com/price",
          currency: "USD"
        })

      # Manually set both times to old (e.g., 25+ hours ago)
      very_old_time =
        DateTime.add(DateTime.utc_now(), -100_000, :second) |> DateTime.truncate(:second)

      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{inserted_at: very_old_time, updated_at: old_time})
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
          price_url: "https://api.example.com/price",
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
          price_url: "https://api.example.com/price",
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
        Assets.update_asset(asset, %{price_url: "https://api.example.com/price"})

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
          price_url: "https://api.example.com/price",
          currency: "USD"
        })

      # Update only the name, keeping same price_url (within 24 hours)
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
          price_url: "https://api.example.com/price",
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
          price_url: "https://api.example.com/price",
          currency: "USD"
        })

      # Set updated_at to 25+ hours ago to trigger price fetch
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset =
        asset
        |> Ecto.Changeset.change(%{updated_at: old_time})
        |> Repo.update!()

      # Store the old updated_at for comparison
      old_updated_at = asset.updated_at

      # Mock for update - API returns SAME price (50.0)
      # This is the key scenario: price value doesn't change
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 50.0}]}}}
      end)

      # Update asset (triggers price fetch because > 24 hours old)
      {:ok, updated_asset} = Assets.update_asset(asset, %{name: "Updated Name"})

      # Assert: Price is still 50.0
      assert Decimal.eq?(updated_asset.price, Decimal.new("50.0"))

      # Critical assertion: updated_at MUST be newer even though price didn't change
      # This ensures rate limiting works correctly
      assert DateTime.compare(updated_asset.updated_at, old_updated_at) == :gt

      # Now update again immediately (within 24 hours)
      # Mock should NOT be called because updated_at was properly set above
      # No expect() call means test fails if HTTP client is invoked
      {:ok, final_asset} = Assets.update_asset(updated_asset, %{name: "Final Name"})

      # Price should still be 50.0 (no fetch happened)
      assert Decimal.eq?(final_asset.price, Decimal.new("50.0"))
      assert final_asset.name == "Final Name"
    end

    test "update_all_prices respects rate limiting for individual assets" do
      # Create 3 assets with price URLs
      HTTPClientMock
      |> expect(:get, 3, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.0}]}}}
      end)

      {:ok, asset1} =
        Assets.create_asset(%{
          name: "Asset 1",
          price_url: "https://api.example.com/asset1",
          currency: "USD"
        })

      {:ok, asset2} =
        Assets.create_asset(%{
          name: "Asset 2",
          price_url: "https://api.example.com/asset2",
          currency: "USD"
        })

      {:ok, asset3} =
        Assets.create_asset(%{
          name: "Asset 3",
          price_url: "https://api.example.com/asset3",
          currency: "USD"
        })

      # Create one asset without price_url - should be ignored
      {:ok, _asset_no_url} =
        Assets.create_asset(%{
          name: "Asset No URL",
          currency: "USD"
        })

      # Set asset1 to old (should be updated)
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset1 =
        asset1
        |> Ecto.Changeset.change(%{updated_at: old_time})
        |> Repo.update!()

      # Set asset2 to old (should be updated)
      asset2 =
        asset2
        |> Ecto.Changeset.change(%{updated_at: old_time})
        |> Repo.update!()

      # asset3 is recent (within 24 hours) - should NOT be updated
      # Store asset3's current updated_at for later comparison
      asset3_old_updated_at = Assets.get_asset!(asset3.id).updated_at

      # Mock: Expect only 2 calls (asset1 and asset2), NOT asset3
      HTTPClientMock
      |> expect(:get, 2, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.0}]}}}
      end)

      # Call update_all_prices
      {:ok, %{success: success_count, errors: error_count}} = Assets.update_all_prices()

      # Should have updated 2 assets (asset1 and asset2)
      # asset3 was skipped due to rate limiting
      # asset_no_url was skipped because no price_url
      assert success_count == 2
      assert error_count == 0

      # Verify asset1 and asset2 were updated
      updated_asset1 = Assets.get_asset!(asset1.id)
      updated_asset2 = Assets.get_asset!(asset2.id)
      updated_asset3 = Assets.get_asset!(asset3.id)

      assert Decimal.eq?(updated_asset1.price, Decimal.new("200.0"))
      assert Decimal.eq?(updated_asset2.price, Decimal.new("200.0"))

      # asset3 should still have original price (not updated due to rate limiting)
      assert Decimal.eq?(updated_asset3.price, Decimal.new("100.0"))

      # Verify updated_at was set for assets that were updated
      assert DateTime.compare(updated_asset1.updated_at, asset1.updated_at) == :gt
      assert DateTime.compare(updated_asset2.updated_at, asset2.updated_at) == :gt

      # Verify asset3's updated_at was NOT changed (rate limited)
      assert DateTime.compare(updated_asset3.updated_at, asset3_old_updated_at) == :eq
    end
  end
end
