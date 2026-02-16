defmodule Boonorbust2Web.UserLiveTest do
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

  describe "edit" do
    test "renders edit form with user data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/user/edit")

      assert html =~ "Edit Profile"
      assert html =~ "Test User"
      assert html =~ "Save Changes"
      assert html =~ "Cancel"
    end

    test "renders currency options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/user/edit")

      assert html =~ "Preferred Currency"
      assert html =~ "USD"
    end
  end

  describe "update" do
    test "updates user name and redirects to dashboard", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/user/edit")

      view
      |> form("form", %{"user" => %{"name" => "New Name", "currency" => "USD"}})
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")

      updated_user = Boonorbust2.Accounts.get_user_by_id(user.id)
      assert updated_user.name == "New Name"
    end

    test "updates user currency and redirects to dashboard", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/user/edit")

      view
      |> form("form", %{"user" => %{"name" => "Test User", "currency" => "SGD"}})
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")

      updated_user = Boonorbust2.Accounts.get_user_by_id(user.id)
      assert updated_user.currency == "SGD"
    end

    test "shows errors when name is blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/user/edit")

      view
      |> form("form", %{"user" => %{"name" => "", "currency" => "USD"}})
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "redirects back to return_to path after save", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/user/edit?return_to=/positions")

      view
      |> form("form", %{"user" => %{"name" => "New Name", "currency" => "USD"}})
      |> render_submit()

      assert_redirect(view, "/positions")

      updated_user = Boonorbust2.Accounts.get_user_by_id(user.id)
      assert updated_user.name == "New Name"
    end

    test "defaults to dashboard when no return_to is provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/user/edit")

      view
      |> form("form", %{"user" => %{"name" => "New Name", "currency" => "USD"}})
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")
    end
  end
end
