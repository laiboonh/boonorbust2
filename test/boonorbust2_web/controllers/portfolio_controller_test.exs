defmodule Boonorbust2Web.PortfolioControllerTest do
  use Boonorbust2Web.ConnCase, async: false

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

  describe "index/2" do
    test "lists all portfolios with tags enriched", %{conn: conn, user: user} do
      # Create a portfolio
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Growth Portfolio",
          user_id: user.id
        })

      # Create tags
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

      # Associate tags with portfolio
      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag1.id)
      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag2.id)

      conn = get(conn, ~p"/portfolios")

      assert html_response(conn, 200)
      portfolios = conn.assigns.portfolios

      assert length(portfolios) == 1

      # Verify controller enriched portfolios with tags
      enriched_portfolio = hd(portfolios)
      assert Map.has_key?(enriched_portfolio, :tags)
      assert length(enriched_portfolio.tags) == 2

      tag_names = Enum.map(enriched_portfolio.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Stocks", "Technology"]
    end

    test "shows empty list when no portfolios exist", %{conn: conn} do
      conn = get(conn, ~p"/portfolios")

      assert html_response(conn, 200)
      assert conn.assigns.portfolios == []
    end
  end

  describe "new/2" do
    test "renders form for new portfolio", %{conn: conn, user: user} do
      # Create some tags
      {:ok, _tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Stocks",
          user_id: user.id
        })

      conn = get(conn, ~p"/portfolios/new")

      assert html_response(conn, 200)
      assert %Ecto.Changeset{} = conn.assigns.changeset
      assert is_list(conn.assigns.all_tags)
      assert length(conn.assigns.all_tags) == 1
    end
  end

  describe "create/2" do
    test "creates portfolio and associates tags", %{conn: conn, user: user} do
      # Create tags
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

      portfolio_params = %{
        "name" => "Test Portfolio"
      }

      # Controller should handle tag_ids as strings (from form)
      conn =
        post(conn, ~p"/portfolios", %{
          "portfolio" => portfolio_params,
          "tag_ids" => [to_string(tag1.id), to_string(tag2.id)]
        })

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify portfolio was created
      portfolios = Boonorbust2.Portfolios.list_portfolios(user.id)
      assert length(portfolios) == 1
      created_portfolio = hd(portfolios)

      # Verify tags were associated (controller logic)
      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(created_portfolio.id)
      assert length(tags) == 2

      tag_names = Enum.map(tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Growth", "Stocks"]
    end

    test "creates portfolio without tags", %{conn: conn, user: user} do
      portfolio_params = %{
        "name" => "No Tags Portfolio"
      }

      conn =
        post(conn, ~p"/portfolios", %{
          "portfolio" => portfolio_params
        })

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify portfolio was created
      portfolios = Boonorbust2.Portfolios.list_portfolios(user.id)
      assert length(portfolios) == 1

      created_portfolio = hd(portfolios)
      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(created_portfolio.id)
      assert tags == []
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      {:ok, _tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Stocks",
          user_id: user.id
        })

      # Invalid: missing name
      portfolio_params = %{
        "name" => ""
      }

      conn =
        post(conn, ~p"/portfolios", %{
          "portfolio" => portfolio_params
        })

      assert html_response(conn, 200)
      assert %Ecto.Changeset{} = conn.assigns.changeset
      assert is_list(conn.assigns.all_tags)
    end
  end

  describe "edit/2" do
    test "renders form for editing portfolio with selected tags", %{conn: conn, user: user} do
      # Create portfolio
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Edit Portfolio",
          user_id: user.id
        })

      # Create tags
      {:ok, tag1} =
        Boonorbust2.Tags.create_tag(%{
          name: "Stocks",
          user_id: user.id
        })

      {:ok, _tag2} =
        Boonorbust2.Tags.create_tag(%{
          name: "Bonds",
          user_id: user.id
        })

      # Associate one tag
      Boonorbust2.Portfolios.add_tag_to_portfolio(portfolio.id, tag1.id)

      conn = get(conn, ~p"/portfolios/#{portfolio.id}/edit")

      assert html_response(conn, 200)
      assert conn.assigns.portfolio.id == portfolio.id
      assert %Ecto.Changeset{} = conn.assigns.changeset
      assert is_list(conn.assigns.all_tags)
      assert length(conn.assigns.all_tags) == 2

      # Verify controller extracts tag IDs for form selection
      assert is_list(conn.assigns.selected_tag_ids)
      assert conn.assigns.selected_tag_ids == [tag1.id]
    end
  end

  describe "update/2" do
    test "updates portfolio and syncs tags", %{conn: conn, user: user} do
      # Create portfolio with initial tag
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

      # Update portfolio with new name and different tags
      portfolio_params = %{
        "name" => "Updated Name"
      }

      conn =
        put(conn, ~p"/portfolios/#{portfolio.id}", %{
          "portfolio" => portfolio_params,
          "tag_ids" => [to_string(tag2.id)]
        })

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify portfolio was updated
      updated_portfolio = Boonorbust2.Portfolios.get_portfolio!(portfolio.id)
      assert updated_portfolio.name == "Updated Name"

      # Verify tags were synced (old removed, new added) - controller logic
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

      # Update without any tags
      portfolio_params = %{
        "name" => "Updated"
      }

      conn =
        put(conn, ~p"/portfolios/#{portfolio.id}", %{
          "portfolio" => portfolio_params
        })

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify all tags were removed
      tags = Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id)
      assert tags == []
    end

    test "renders errors when update data is invalid", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Portfolio",
          user_id: user.id
        })

      {:ok, _tag} =
        Boonorbust2.Tags.create_tag(%{
          name: "Tag",
          user_id: user.id
        })

      # Invalid: empty name
      portfolio_params = %{
        "name" => ""
      }

      conn =
        put(conn, ~p"/portfolios/#{portfolio.id}", %{
          "portfolio" => portfolio_params
        })

      assert html_response(conn, 200)
      assert conn.assigns.portfolio.id == portfolio.id
      assert %Ecto.Changeset{} = conn.assigns.changeset
      assert is_list(conn.assigns.all_tags)
      assert is_list(conn.assigns.selected_tag_ids)
    end
  end

  describe "delete/2" do
    test "deletes chosen portfolio", %{conn: conn, user: user} do
      {:ok, portfolio} =
        Boonorbust2.Portfolios.create_portfolio(%{
          name: "Delete Me",
          user_id: user.id
        })

      conn = delete(conn, ~p"/portfolios/#{portfolio.id}")

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify portfolio was deleted
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

      # Verify tag is associated
      assert length(Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id)) == 1

      conn = delete(conn, ~p"/portfolios/#{portfolio.id}")

      assert redirected_to(conn) == ~p"/portfolios"

      # Verify portfolio was deleted
      assert Boonorbust2.Portfolios.get_portfolio(portfolio.id) == nil

      # Verify portfolio_tag associations were cleaned up
      assert Boonorbust2.Portfolios.list_tags_for_portfolio(portfolio.id) == []

      # Verify tag itself still exists
      assert Boonorbust2.Tags.get_tag!(tag.id) != nil
    end

    test "returns not found for non-existent portfolio", %{conn: conn} do
      conn = delete(conn, ~p"/portfolios/999999")

      assert conn.status == 404
      assert response(conn, 404) =~ "Portfolio not found"
    end
  end
end
