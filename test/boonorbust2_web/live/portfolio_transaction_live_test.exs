defmodule Boonorbust2Web.PortfolioTransactionLiveTest do
  use Boonorbust2Web.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    {:ok, user} =
      Boonorbust2.Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        provider: "google",
        uid: "test123",
        currency: "USD"
      })

    {:ok, asset} =
      Boonorbust2.Assets.create_asset(%{
        name: "Test Stock",
        currency: "USD"
      })

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{user_id: user.id})
      |> assign(:current_user, user)

    {:ok, conn: conn, user: user, asset: asset}
  end

  defp create_transaction(user, asset, attrs \\ %{}) do
    default_attrs = %{
      "user_id" => user.id,
      "asset_id" => asset.id,
      "action" => "buy",
      "quantity" => "100",
      "price" => "10.00",
      "commission" => "5.00",
      "transaction_date" => "2024-01-15T10:00:00Z",
      "notes" => nil
    }

    {:ok, transaction} =
      Boonorbust2.PortfolioTransactions.create_portfolio_transaction(
        Map.merge(default_attrs, attrs)
      )

    transaction
  end

  describe "index" do
    test "lists all transactions", %{conn: conn, user: user, asset: asset} do
      create_transaction(user, asset)

      {:ok, _view, html} = live(conn, ~p"/portfolio_transactions")

      assert html =~ "Test Stock"
      assert html =~ "BUY"
    end

    test "shows empty list when no transactions exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/portfolio_transactions")

      assert html =~ "Add Transaction"
      assert html =~ "Import CSV"
    end

    test "filters transactions by asset name", %{conn: conn, user: user, asset: asset} do
      {:ok, other_asset} =
        Boonorbust2.Assets.create_asset(%{name: "Other Stock", currency: "USD"})

      create_transaction(user, asset)
      create_transaction(user, other_asset, %{"asset_id" => other_asset.id})

      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view
      |> form(~s|form[phx-submit="filter"]|, %{"filter" => "Test Stock"})
      |> render_submit()

      html = render(view)
      assert html =~ "Test Stock"
      refute html =~ "Other Stock"
    end

    test "clears filter", %{conn: conn, user: user, asset: asset} do
      create_transaction(user, asset)

      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view
      |> form(~s|form[phx-submit="filter"]|, %{"filter" => "Test Stock"})
      |> render_submit()

      view |> element(~s|button[phx-click="clear_filter"]|) |> render_click()

      html = render(view)
      assert html =~ "Test Stock"
    end
  end

  describe "create" do
    test "prefills transaction date with current datetime", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()

      html = render(view)
      # datetime-local requires YYYY-MM-DDTHH:MM format (no seconds)
      expected = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:")
      assert html =~ ~s|value="#{expected}|
    end

    test "creates transaction via modal", %{conn: conn, asset: asset} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()
      assert render(view) =~ "Add New Transaction"

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "transaction" => %{
          "asset_id" => to_string(asset.id),
          "action" => "buy",
          "quantity" => "100",
          "price" => "10.00",
          "commission" => "5.00",
          "transaction_date" => "2024-01-15T10:00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Test Stock"
      assert html =~ "BUY"
      refute html =~ "Add New Transaction"
    end

    test "shows errors when data is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "transaction" => %{
          "asset_id" => "",
          "action" => "",
          "quantity" => "",
          "price" => "",
          "commission" => "",
          "transaction_date" => ""
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "cancel button closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()
      assert render(view) =~ "Add New Transaction"

      view |> element(~s|button[phx-click="close_modal"]|, "Cancel") |> render_click()
      refute render(view) =~ "Add New Transaction"
    end

    test "close button closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()
      assert render(view) =~ "Add New Transaction"

      view |> element(~s|button.text-gray-400[phx-click="close_modal"]|) |> render_click()
      refute render(view) =~ "Add New Transaction"
    end

    test "preserves form values on create error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Add Transaction") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "transaction" => %{
          "asset_id" => "",
          "action" => "buy",
          "quantity" => "100",
          "price" => "",
          "commission" => "5",
          "transaction_date" => ""
        }
      })
      |> render_submit()

      html = render(view)
      # Modal should still be open
      assert html =~ "Add New Transaction"
      # Values should be preserved
      assert html =~ ~s|value="100"|
    end
  end

  describe "update" do
    test "updates transaction via edit modal", %{conn: conn, user: user, asset: asset} do
      transaction = create_transaction(user, asset)

      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{transaction.id}"]|)
      |> render_click()

      assert render(view) =~ "Edit Transaction"

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "transaction_id" => to_string(transaction.id),
        "transaction" => %{
          "asset_id" => to_string(asset.id),
          "action" => "buy",
          "quantity" => "50",
          "price" => "15.00",
          "commission" => "5.00",
          "transaction_date" => "2024-02-15T10:00"
        }
      })
      |> render_submit()

      html = render(view)
      refute html =~ "Edit Transaction"

      updated =
        Boonorbust2.PortfolioTransactions.get_portfolio_transaction!(transaction.id, user.id)

      assert updated.action == "buy"
      assert Decimal.equal?(updated.quantity, Decimal.new("50"))
    end

    test "shows errors when update data is invalid", %{conn: conn, user: user, asset: asset} do
      transaction = create_transaction(user, asset)

      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{transaction.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "transaction_id" => to_string(transaction.id),
        "transaction" => %{
          "asset_id" => to_string(asset.id),
          "action" => "buy",
          "quantity" => "0",
          "price" => "10.00",
          "commission" => "5.00",
          "transaction_date" => "2024-01-15T10:00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "must be greater than 0"
    end

    test "preserves form values on update error", %{conn: conn, user: user, asset: asset} do
      transaction = create_transaction(user, asset)

      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{transaction.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "transaction_id" => to_string(transaction.id),
        "transaction" => %{
          "asset_id" => to_string(asset.id),
          "action" => "buy",
          "quantity" => "0",
          "price" => "10.00",
          "commission" => "5.00",
          "transaction_date" => "2024-01-15T10:00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Edit Transaction"
      assert html =~ ~s|value="0"|
    end
  end

  describe "delete" do
    test "deletes chosen transaction", %{conn: conn, user: user, asset: asset} do
      transaction = create_transaction(user, asset)

      {:ok, view, html} = live(conn, ~p"/portfolio_transactions")
      assert html =~ "Test Stock"

      view
      |> element(~s|button[phx-click="delete"][phx-value-id="#{transaction.id}"]|)
      |> render_click()

      assert Boonorbust2.PortfolioTransactions.get_portfolio_transaction(transaction.id, user.id) ==
               nil
    end
  end

  describe "pagination" do
    test "paginates transactions", %{conn: conn, user: user, asset: asset} do
      # Create 11 transactions to get 2 pages (page_size=10)
      for i <- 1..11 do
        date = DateTime.add(~U[2024-01-01 10:00:00Z], i * 86_400) |> DateTime.to_iso8601()

        create_transaction(user, asset, %{
          "transaction_date" => date
        })
      end

      {:ok, view, html} = live(conn, ~p"/portfolio_transactions")

      assert html =~ "Page 1 of 2"

      view
      |> element(~s|button[phx-click="page"][phx-value-page="2"]|)
      |> render_click()

      html = render(view)
      assert html =~ "Page 2 of 2"
    end
  end

  describe "csv import" do
    test "opens and closes csv modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio_transactions")

      view |> element("button", "Import CSV") |> render_click()
      assert render(view) =~ "Import CSV File"

      view |> element(~s|button[phx-click="close_csv_modal"]|, "Cancel") |> render_click()
      refute render(view) =~ "Import CSV File"
    end
  end

  describe "format_import_result_message" do
    test "formats success message correctly when all imports succeed" do
      message = Boonorbust2.PortfolioTransactions.format_import_result_message(5, 0, 5)
      assert message == "Successfully imported 5 transactions"
    end

    test "formats message with error count when some imports fail" do
      message = Boonorbust2.PortfolioTransactions.format_import_result_message(3, 2, 5)
      assert message == "Imported 3 of 5 transactions (2 errors)"
    end

    test "formats message correctly when all imports fail" do
      message = Boonorbust2.PortfolioTransactions.format_import_result_message(0, 5, 5)
      assert message == "Imported 0 of 5 transactions (5 errors)"
    end
  end
end
