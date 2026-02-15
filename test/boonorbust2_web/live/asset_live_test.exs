defmodule Boonorbust2Web.AssetLiveTest do
  use Boonorbust2Web.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Boonorbust2.Assets
  alias Boonorbust2.HTTPClientMock

  setup :verify_on_exit!

  setup do
    Application.put_env(:boonorbust2, :admins, ["admin@example.com"])

    {:ok, admin_user} =
      Boonorbust2.Accounts.create_user(%{
        email: "admin@example.com",
        name: "Admin User",
        provider: "google",
        uid: "admin123",
        currency: "USD"
      })

    {:ok, regular_user} =
      Boonorbust2.Accounts.create_user(%{
        email: "user@example.com",
        name: "Regular User",
        provider: "google",
        uid: "user123",
        currency: "USD"
      })

    admin_conn =
      build_conn()
      |> Plug.Test.init_test_session(%{user_id: admin_user.id})
      |> assign(:current_user, admin_user)

    user_conn =
      build_conn()
      |> Plug.Test.init_test_session(%{user_id: regular_user.id})
      |> assign(:current_user, regular_user)

    {:ok,
     admin_conn: admin_conn,
     user_conn: user_conn,
     admin_user: admin_user,
     regular_user: regular_user}
  end

  defp create_asset(attrs \\ %{}) do
    default_attrs = %{name: "Test Stock", currency: "USD"}
    {:ok, asset} = Assets.create_asset(Map.merge(default_attrs, attrs))
    asset
  end

  describe "index" do
    test "lists assets", %{admin_conn: conn} do
      create_asset(%{name: "Apple Inc."})

      {:ok, _view, html} = live(conn, ~p"/assets")

      assert html =~ "Apple Inc."
    end

    test "shows empty list when no assets exist", %{admin_conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/assets")

      assert html =~ "Add Asset"
    end

    test "filters assets by name", %{admin_conn: conn} do
      create_asset(%{name: "Apple Inc."})
      create_asset(%{name: "Google LLC"})

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> form(~s|form[phx-submit="filter"]|, %{"filter" => "Apple"})
      |> render_submit()

      html = render(view)
      assert html =~ "Apple Inc."
      refute html =~ "Google LLC"
    end

    test "clears filter", %{admin_conn: conn} do
      create_asset(%{name: "Apple Inc."})
      create_asset(%{name: "Google LLC"})

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> form(~s|form[phx-submit="filter"]|, %{"filter" => "Apple"})
      |> render_submit()

      view |> element(~s|button[phx-click="clear_filter"]|) |> render_click()

      html = render(view)
      assert html =~ "Apple Inc."
      assert html =~ "Google LLC"
    end
  end

  describe "admin vs non-admin" do
    test "admin sees Add Asset and Update Prices buttons", %{admin_conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/assets")

      assert html =~ "Add Asset"
      assert html =~ "Update Prices"
    end

    test "non-admin does not see Add Asset or Update Prices buttons", %{user_conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/assets")

      refute html =~ "Add Asset"
      refute html =~ "Update Prices"
    end

    test "admin sees edit and delete buttons for assets", %{admin_conn: conn} do
      create_asset()

      {:ok, _view, html} = live(conn, ~p"/assets")

      assert html =~ "Edit asset"
      assert html =~ "Delete asset"
    end

    test "non-admin does not see edit and delete buttons", %{user_conn: conn} do
      create_asset()

      {:ok, _view, html} = live(conn, ~p"/assets")

      refute html =~ "Edit asset"
      refute html =~ "Delete asset"
    end
  end

  describe "create" do
    test "creates asset via modal", %{admin_conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/assets")

      view |> element("button", "Add Asset") |> render_click()
      assert render(view) =~ "Add New Asset"

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "asset" => %{
          "name" => "New Stock",
          "currency" => "USD"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "New Stock"
      refute html =~ "Add New Asset"
    end

    test "shows errors when data is invalid", %{admin_conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/assets")

      view |> element("button", "Add Asset") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "asset" => %{
          "name" => "",
          "currency" => ""
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "cancel button closes the modal", %{admin_conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/assets")

      view |> element("button", "Add Asset") |> render_click()
      assert render(view) =~ "Add New Asset"

      view |> element(~s|button[phx-click="close_modal"]|, "Cancel") |> render_click()
      refute render(view) =~ "Add New Asset"
    end

    test "close button closes the modal", %{admin_conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/assets")

      view |> element("button", "Add Asset") |> render_click()
      assert render(view) =~ "Add New Asset"

      view |> element(~s|button.text-gray-400[phx-click="close_modal"]|) |> render_click()
      refute render(view) =~ "Add New Asset"
    end
  end

  describe "update" do
    test "updates asset via edit modal", %{admin_conn: conn} do
      asset = create_asset(%{name: "Old Name"})

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      assert render(view) =~ "Edit Asset"

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "asset_id" => to_string(asset.id),
        "asset" => %{
          "name" => "New Name",
          "currency" => "USD"
        }
      })
      |> render_submit()

      html = render(view)
      refute html =~ "Edit Asset"

      updated = Assets.get_asset!(asset.id)
      assert updated.name == "New Name"
    end

    test "preserves dividend withholding tax on re-edit", %{admin_conn: conn} do
      # Insert directly to avoid dividend URL fetch during create
      asset =
        %Boonorbust2.Assets.Asset{}
        |> Ecto.Changeset.change(%{
          name: "Div Asset",
          currency: "USD",
          distributes_dividends: true,
          dividend_url: "https://example.com/div",
          dividend_withholding_tax: Decimal.new("0.15")
        })
        |> Boonorbust2.Repo.insert!()

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ ~s|value="0.15" selected|
    end

    test "preserves 0% dividend withholding tax on re-edit", %{admin_conn: conn} do
      asset =
        %Boonorbust2.Assets.Asset{}
        |> Ecto.Changeset.change(%{
          name: "Zero Tax Asset",
          currency: "USD",
          distributes_dividends: true,
          dividend_url: "https://example.com/div",
          dividend_withholding_tax: Decimal.new("0.0")
        })
        |> Boonorbust2.Repo.insert!()

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ ~s|value="0" selected|
    end

    test "shows errors when update data is invalid", %{admin_conn: conn} do
      asset = create_asset()

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "asset_id" => to_string(asset.id),
        "asset" => %{
          "name" => "",
          "currency" => "USD"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "delete" do
    test "deletes chosen asset", %{admin_conn: conn} do
      asset = create_asset(%{name: "To Delete"})

      {:ok, view, html} = live(conn, ~p"/assets")
      assert html =~ "To Delete"

      view
      |> element(~s|button[phx-click="delete"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      assert Assets.get_asset(asset.id) == nil
    end
  end

  describe "update_all_prices" do
    @tag :capture_log
    test "updates all prices and shows result", %{admin_conn: conn, regular_user: regular_user} do
      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 100.0}]}}}
      end)

      {:ok, asset} =
        Assets.create_asset(%{
          name: "Priced Stock",
          price_url: "https://api.marketstack.com/stock",
          currency: "USD"
        })

      {:ok, _} =
        Boonorbust2.PortfolioTransactions.create_portfolio_transaction(%{
          "asset_id" => asset.id,
          "user_id" => regular_user.id,
          "action" => "buy",
          "quantity" => "10",
          "price" => "100.0",
          "currency" => "USD",
          "commission" => "0",
          "transaction_date" => DateTime.utc_now()
        })

      Boonorbust2.PortfolioPositions.calculate_and_upsert_positions_for_asset(
        asset.id,
        regular_user.id
      )

      # Make asset old so it gets updated
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second) |> DateTime.truncate(:second)

      asset
      |> Ecto.Changeset.change(%{updated_at: old_time})
      |> Boonorbust2.Repo.update!()

      HTTPClientMock
      |> expect(:get, 1, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"data" => [%{"close" => 200.0}]}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/assets")

      view |> element(~s|button[phx-click="update_all_prices"]|) |> render_click()

      html = render(view)
      assert html =~ "Successfully updated"
    end
  end

  describe "dividends modal" do
    test "opens and closes dividends modal", %{admin_conn: conn} do
      # Insert directly to bypass URL fetching during create
      asset =
        %Boonorbust2.Assets.Asset{}
        |> Ecto.Changeset.change(%{
          name: "Dividend Stock",
          currency: "USD",
          distributes_dividends: true,
          dividend_url: "https://example.com/dividends",
          dividend_withholding_tax: Decimal.new("0.15")
        })
        |> Boonorbust2.Repo.insert!()

      {:ok, view, _html} = live(conn, ~p"/assets")

      view
      |> element(~s|button[phx-click="show_dividends"][phx-value-id="#{asset.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ "Dividends for Dividend Stock"
      assert html =~ "No dividends recorded"

      view |> element(~s|button[phx-click="close_dividends_modal"]|) |> render_click()
      refute render(view) =~ "Dividends for Dividend Stock"
    end
  end

  describe "format_update_result_message" do
    test "formats success message correctly when all updates succeed" do
      message =
        Assets.format_update_result_message(%{
          prices_success: 5,
          prices_errors: 0,
          dividends_success: 3,
          dividends_errors: 0
        })

      assert message == "Successfully updated 5 prices and 3 dividends"
    end

    test "formats message with error count when some updates fail" do
      message =
        Assets.format_update_result_message(%{
          prices_success: 3,
          prices_errors: 2,
          dividends_success: 1,
          dividends_errors: 1
        })

      assert message =~ "3 prices"
      assert message =~ "1 dividends"
      assert message =~ "3 errors"
    end
  end
end
