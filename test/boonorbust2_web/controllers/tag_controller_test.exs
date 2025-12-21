defmodule Boonorbust2Web.TagControllerTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox

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

  describe "add_tag_to_asset/2" do
    test "creates new tag and adds to asset", %{conn: conn, user: user} do
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

      # Controller should handle asset_id as string (from URL path)
      conn =
        post(conn, ~p"/tags/#{asset.id}", %{
          "tag_name" => "Technology"
        })

      assert html_response(conn, 200)

      # Verify tag was created and associated
      tags = Boonorbust2.Tags.list_tags_for_asset(asset.id, user.id)
      assert length(tags) == 1
      assert hd(tags).name == "Technology"
    end

    test "adds existing tag to asset", %{conn: conn, user: user} do
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

      # Create tag first
      {:ok, _tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Existing Tag",
          user_id: user.id
        })

      conn =
        post(conn, ~p"/tags/#{asset.id}", %{
          "tag_name" => "Existing Tag"
        })

      assert html_response(conn, 200)

      # Verify tag was associated
      tags = Boonorbust2.Tags.list_tags_for_asset(asset.id, user.id)
      assert length(tags) == 1
      assert hd(tags).name == "Existing Tag"
    end

    test "renders tags list after adding tag", %{conn: conn, user: _user} do
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

      conn =
        post(conn, ~p"/tags/#{asset.id}", %{
          "tag_name" => "New Tag"
        })

      # Verify response includes updated tags list
      assert html_response(conn, 200)
      assert conn.assigns.asset_id == asset.id
      assert is_list(conn.assigns.tags)
      assert length(conn.assigns.tags) == 1
    end

    test "handles parameter type conversion (string to integer)", %{conn: conn, user: user} do
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

      # Asset ID comes as string from URL path - controller must convert
      conn =
        post(conn, ~p"/tags/#{asset.id}", %{
          "tag_name" => "Tag"
        })

      assert html_response(conn, 200)

      # If conversion worked, tag should be added
      tags = Boonorbust2.Tags.list_tags_for_asset(asset.id, user.id)
      assert length(tags) == 1
    end

    @tag :capture_log
    test "returns error when tag creation fails", %{conn: conn, user: _user} do
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

      # Empty tag name should fail
      conn =
        post(conn, ~p"/tags/#{asset.id}", %{
          "tag_name" => ""
        })

      assert html_response(conn, 422)
    end
  end

  describe "remove_tag_from_asset/2" do
    test "removes tag from asset", %{conn: conn, user: user} do
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

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Remove Me",
          user_id: user.id
        })

      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag.id)

      # Controller should handle both asset_id and tag_id as strings from URL path
      conn = delete(conn, ~p"/tags/#{asset.id}/#{tag.id}")

      assert html_response(conn, 200)

      # Verify tag was removed
      tags = Boonorbust2.Tags.list_tags_for_asset(asset.id, user.id)
      assert tags == []
    end

    test "handles parameter type conversion for asset_id and tag_id", %{conn: conn, user: user} do
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

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Tag",
          user_id: user.id
        })

      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag.id)

      # Both IDs come as strings from URL path - controller must convert both
      conn = delete(conn, ~p"/tags/#{asset.id}/#{tag.id}")

      assert html_response(conn, 200)

      # If conversion worked, tag should be removed
      tags = Boonorbust2.Tags.list_tags_for_asset(asset.id, user.id)
      assert tags == []
    end

    test "renders updated tags list after removal", %{conn: conn, user: user} do
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

      {:ok, tag1} =
        Boonorbust2.Tags.create_tag(%{
          name: "Keep Me",
          user_id: user.id
        })

      {:ok, tag2} =
        Boonorbust2.Tags.create_tag(%{
          name: "Remove Me",
          user_id: user.id
        })

      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag1.id)
      Boonorbust2.Tags.add_tag_to_asset(asset.id, tag2.id)

      conn = delete(conn, ~p"/tags/#{asset.id}/#{tag2.id}")

      # Verify response includes updated tags list
      assert html_response(conn, 200)
      assert conn.assigns.asset_id == asset.id
      assert is_list(conn.assigns.tags)
      assert length(conn.assigns.tags) == 1
      assert hd(conn.assigns.tags).name == "Keep Me"
    end

    test "returns error when tag not found", %{conn: conn, user: _user} do
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

      # Try to remove non-existent tag
      conn = delete(conn, ~p"/tags/#{asset.id}/99999")

      assert html_response(conn, 404)
    end
  end
end
