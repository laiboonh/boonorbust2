defmodule Boonorbust2Web.UserEditTest do
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

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{user_id: user.id})
      |> assign(:current_user, user)

    {:ok, conn: conn, user: user}
  end

  describe "user edit modal" do
    test "opens modal when clicking user name", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard")

      refute html =~ "Edit Profile"

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()

      html = render(view)
      assert html =~ "Edit Profile"
      assert html =~ "Save Changes"
      assert html =~ "Cancel"
    end

    test "closes modal when clicking cancel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()
      assert render(view) =~ "Edit Profile"

      view |> element(~s|button[phx-click="close_user_edit"]|, "Cancel") |> render_click()
      refute render(view) =~ "Edit Profile"
    end

    test "closes modal when clicking X button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()
      assert render(view) =~ "Edit Profile"

      view |> element(~s|button.text-gray-400[phx-click="close_user_edit"]|) |> render_click()
      refute render(view) =~ "Edit Profile"
    end

    test "updates user name and closes modal", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="save_user"]|, %{
        "user" => %{"name" => "New Name", "currency" => "USD"}
      })
      |> render_submit()

      html = render(view)
      refute html =~ "Edit Profile"
      assert html =~ "New Name"

      updated_user = Boonorbust2.Accounts.get_user_by_id(user.id)
      assert updated_user.name == "New Name"
    end

    test "updates user currency and closes modal", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="save_user"]|, %{
        "user" => %{"name" => "Test User", "currency" => "SGD"}
      })
      |> render_submit()

      refute render(view) =~ "Edit Profile"

      updated_user = Boonorbust2.Accounts.get_user_by_id(user.id)
      assert updated_user.currency == "SGD"
    end

    test "shows errors when name is blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="save_user"]|, %{
        "user" => %{"name" => "", "currency" => "USD"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Edit Profile"
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "stays on current page after save", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/positions")

      view |> element(~s|a[phx-click="open_user_edit"]|) |> render_click()

      view
      |> form(~s|form[phx-submit="save_user"]|, %{
        "user" => %{"name" => "New Name", "currency" => "USD"}
      })
      |> render_submit()

      html = render(view)
      refute html =~ "Edit Profile"
      assert html =~ "New Name"
    end
  end
end
