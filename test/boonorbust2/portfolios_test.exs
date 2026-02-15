defmodule Boonorbust2.PortfoliosTest do
  use Boonorbust2.DataCase, async: false

  alias Boonorbust2.Portfolios
  alias Boonorbust2.Tags

  setup do
    {:ok, user} =
      Boonorbust2.Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        provider: "google",
        uid: "test123",
        currency: "USD"
      })

    {:ok, user: user}
  end

  describe "delete_portfolio_by_id/1" do
    test "deletes existing portfolio", %{user: user} do
      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(%{
          name: "Test Portfolio",
          user_id: user.id
        })

      assert :ok = Portfolios.delete_portfolio_by_id(portfolio.id)
      assert Portfolios.get_portfolio(portfolio.id) == nil
    end

    test "deletes portfolio and its associated tags", %{user: user} do
      {:ok, tag1} =
        Tags.create_tag(%{
          name: "Tag1",
          user_id: user.id
        })

      {:ok, tag2} =
        Tags.create_tag(%{
          name: "Tag2",
          user_id: user.id
        })

      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(
          %{name: "Portfolio with Tags", user_id: user.id},
          [tag1.id, tag2.id]
        )

      # Verify tags are associated
      assert length(Portfolios.list_tags_for_portfolio(portfolio.id)) == 2

      # Delete portfolio
      assert :ok = Portfolios.delete_portfolio_by_id(portfolio.id)

      # Verify portfolio is deleted
      assert Portfolios.get_portfolio(portfolio.id) == nil

      # Verify portfolio_tags entries are cleaned up
      assert Portfolios.list_tags_for_portfolio(portfolio.id) == []

      # Verify tags themselves still exist
      assert Tags.get_tag!(tag1.id) != nil
      assert Tags.get_tag!(tag2.id) != nil
    end
  end
end
