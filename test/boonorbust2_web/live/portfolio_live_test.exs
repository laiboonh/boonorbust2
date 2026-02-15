defmodule Boonorbust2Web.PortfolioLiveTest do
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

  describe "index" do
    test "lists all portfolios with tags", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Growth Portfolio",
          user_id: user.id
        })

      {:ok, tag1} =
        Boonorbust2.Tags.create_tag(%{
          name: "Stocks",
          user_id: user.id
        })

      {:ok, tag2} =
        Boonorbust2.Tags.create_tag(%{
          name: "Technology",
          user_id: user.id
        })

      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag1.id)
      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag2.id)

      {:ok, _view, html} = live(conn, ~p"/portfolios")

      assert html =~ "Growth Portfolio"
      assert html =~ "Stocks"
      assert html =~ "Technology"
    end

    test "shows empty list when no portfolios exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/portfolios")

      assert html =~ "Add Portfolio"
      refute html =~ "bg-white rounded-lg shadow p-6"
    end
  end

  describe "create" do
    test "creates portfolio with tags", %{conn: conn, user: user} do
      {:ok, tag1} =
        Boonorbust2.Tags.create_tag(%{
          name: "Stocks",
          user_id: user.id
        })

      {:ok, tag2} =
        Boonorbust2.Tags.create_tag(%{
          name: "Growth",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()

      assert render(view) =~ "Add New Portfolio"

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "portfolio" => %{"name" => "Test Portfolio"},
        "tag_ids" => [to_string(tag1.id), to_string(tag2.id)]
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Test Portfolio"
      refute html =~ "Add New Portfolio"

      portfolios = Boonorbust2.Portfolios.list_portfolios(user.id)
      assert length(portfolios) == 1

      created_portfolio = hd(portfolios)
      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(created_portfolio.id)
      assert length(tags) == 2
    end

    test "creates portfolio without tags", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "portfolio" => %{"name" => "No Tags Portfolio"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "No Tags Portfolio"

      portfolios = Boonorbust2.Portfolios.list_portfolios(user.id)
      assert length(portfolios) == 1

      created_portfolio = hd(portfolios)
      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(created_portfolio.id)
      assert tags == []
    end

    test "shows errors when data is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "portfolio" => %{"name" => ""}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "shows error for duplicate name", %{conn: conn, user: user} do
      Boonorbust2.Portfolios.create_portfolio(%{
        name: "Existing Portfolio",
        user_id: user.id
      })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()

      view
      |> form(~s|form[phx-submit="save"]|, %{
        "portfolio" => %{"name" => "Existing Portfolio"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Name has already been taken"
    end

    test "cancel button closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()
      assert render(view) =~ "Add New Portfolio"

      view |> element(~s|button[phx-click="close_modal"]|, "Cancel") |> render_click()
      refute render(view) =~ "Add New Portfolio"
    end

    test "close button closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view |> element("button", "Add Portfolio") |> render_click()
      assert render(view) =~ "Add New Portfolio"

      view |> element(~s|button.text-gray-400[phx-click="close_modal"]|) |> render_click()
      refute render(view) =~ "Add New Portfolio"
    end
  end

  describe "update" do
    test "updates portfolio and syncs tags", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Original Name",
          user_id: user.id
        })

      {:ok, tag1} =
        Boonorbust2.Tags.create_tag(%{
          name: "Old Tag",
          user_id: user.id
        })

      {:ok, tag2} =
        Boonorbust2.Tags.create_tag(%{
          name: "New Tag",
          user_id: user.id
        })

      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag1.id)

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      # Click edit to open the edit form
      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      assert render(view) =~ "Edit Portfolio"

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => "Updated Name"},
        "tag_ids" => [to_string(tag2.id)]
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Updated Name"
      refute html =~ "Edit Portfolio"

      updated_portfolio = Boonorbust2.Portfolios.get_portfolio!(portfolio.id)
      assert updated_portfolio.name == "Updated Name"

      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id)
      assert length(tags) == 1
      assert hd(tags).name == "New Tag"
    end

    test "updates portfolio and removes all tags", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Portfolio",
          user_id: user.id
        })

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Tag",
          user_id: user.id
        })

      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag.id)

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => "Updated"},
        "tag_ids" => []
      })
      |> render_submit()

      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id)
      assert tags == []
    end

    test "updates portfolio description without changing name", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "My Portfolio",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => "My Portfolio", "description" => "New description"}
      })
      |> render_submit()

      updated = Boonorbust2.Portfolios.get_portfolio!(portfolio.id)
      assert updated.name == "My Portfolio"
      assert updated.description == "New description"
    end

    test "shows error when renaming to an existing portfolio name", %{conn: conn, user: user} do
      Boonorbust2.Portfolios.create_portfolio(%{
        name: "Portfolio A",
        user_id: user.id
      })

      {:ok, portfolio_b} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Portfolio B",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio_b.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio_b.id),
        "portfolio" => %{"name" => "Portfolio A"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Name has already been taken"
    end

    test "shows errors when update data is invalid", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Portfolio",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => ""}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "preserves submitted name on update error", %{conn: conn, user: user} do
      Boonorbust2.Portfolios.create_portfolio(%{
        name: "Existing",
        user_id: user.id
      })

      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "My Portfolio",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => "Existing"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Name has already been taken"
      assert html =~ ~s|value="Existing"|
    end

    test "preserves selected tags on update error", %{conn: conn, user: user} do
      Boonorbust2.Portfolios.create_portfolio(%{
        name: "Existing",
        user_id: user.id
      })

      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "My Portfolio",
          user_id: user.id
        })

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Keep This Tag",
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="edit"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      view
      |> form(~s|form[phx-submit="update"]|, %{
        "portfolio_id" => to_string(portfolio.id),
        "portfolio" => %{"name" => "Existing"},
        "tag_ids" => [to_string(tag.id)]
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Name has already been taken"
      assert html =~ ~s|selected|
      assert html =~ "Keep This Tag"
    end
  end

  describe "delete" do
    test "deletes chosen portfolio", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Delete Me",
          user_id: user.id
        })

      {:ok, view, html} = live(conn, ~p"/portfolios")
      assert html =~ "Delete Me"

      view
      |> element(~s|button[phx-click="delete"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      html = render(view)
      refute html =~ "Delete Me"
      assert Boonorbust2.Portfolios.get_portfolio(portfolio.id) == nil
    end

    test "deletes portfolio and cleans up associated tags", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Portfolio with Tags",
          user_id: user.id
        })

      {:ok, tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Test Tag",
          user_id: user.id
        })

      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag.id)

      assert length(Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id)) == 1

      {:ok, view, _html} = live(conn, ~p"/portfolios")

      view
      |> element(~s|button[phx-click="delete"][phx-value-id="#{portfolio.id}"]|)
      |> render_click()

      assert Boonorbust2.Portfolios.get_portfolio(portfolio.id) == nil
      assert Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id) == []
      assert Boonorbust2.Tags.get_tag!(tag.id) != nil
    end
  end
end
