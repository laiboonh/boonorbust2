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
  end
end
