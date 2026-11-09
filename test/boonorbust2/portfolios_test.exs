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
          %{tag1.id => "50", tag2.id => "50"}
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

  describe "validate_tag_allocations/1" do
    test "returns :ok for an empty map" do
      assert Portfolios.validate_tag_allocations(%{}) == :ok
    end

    test "returns :ok when percentages sum to exactly 100" do
      assert Portfolios.validate_tag_allocations(%{"1" => "100"}) == :ok
      assert Portfolios.validate_tag_allocations(%{"1" => "40", "2" => "60"}) == :ok

      assert Portfolios.validate_tag_allocations(%{
               "1" => "33.33",
               "2" => "33.33",
               "3" => "33.34"
             }) == :ok
    end

    test "returns an error when percentages do not sum to 100" do
      assert {:error, _} =
               Portfolios.validate_tag_allocations(%{
                 "1" => "33.33",
                 "2" => "33.33",
                 "3" => "33.33"
               })

      assert {:error, _} = Portfolios.validate_tag_allocations(%{"1" => "40", "2" => "50"})
    end

    test "returns an error when a selected tag's percentage is blank or nil" do
      assert {:error, _} = Portfolios.validate_tag_allocations(%{"1" => "40", "2" => ""})
      assert {:error, _} = Portfolios.validate_tag_allocations(%{"1" => "40", "2" => nil})
    end
  end

  describe "create_portfolio_with_tags/2 with tag allocations" do
    test "persists each tag's target allocation percentage", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(
          %{name: "Split Portfolio", user_id: user.id},
          %{tag1.id => "40", tag2.id => "60"}
        )

      [loaded] = Portfolios.list_portfolios_with_tags(user.id)
      assert loaded.id == portfolio.id

      percentages = loaded.tags |> Enum.map(&{&1.name, &1.target_allocation_percent}) |> Map.new()

      assert Decimal.equal?(percentages["Growth"], Decimal.new("40"))
      assert Decimal.equal?(percentages["Income"], Decimal.new("60"))
    end

    test "rejects a split that does not sum to 100 and creates no portfolio", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      assert {:error, changeset} =
               Portfolios.create_portfolio_with_tags(
                 %{name: "Bad Split", user_id: user.id},
                 %{tag1.id => "40", tag2.id => "50"}
               )

      assert %{tag_allocations: [_]} = errors_on(changeset)
      assert Portfolios.list_portfolios(user.id) == []
    end

    test "rejects a selected tag with a blank percentage", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      assert {:error, changeset} =
               Portfolios.create_portfolio_with_tags(
                 %{name: "Blank Split", user_id: user.id},
                 %{tag1.id => "40", tag2.id => ""}
               )

      assert %{tag_allocations: [_]} = errors_on(changeset)
      assert Portfolios.list_portfolios(user.id) == []
    end

    test "creates a portfolio with no tags when the allocation map is empty", %{user: user} do
      assert {:ok, portfolio} =
               Portfolios.create_portfolio_with_tags(%{name: "No Tags", user_id: user.id}, %{})

      assert Portfolios.list_tags_for_portfolio(portfolio.id) == []
    end

    test "rejects an individually out-of-range percentage even if the sum is 100", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      assert {:error, changeset} =
               Portfolios.create_portfolio_with_tags(
                 %{name: "Out Of Range", user_id: user.id},
                 %{tag1.id => "150", tag2.id => "-50"}
               )

      assert %{tag_allocations: [_]} = errors_on(changeset)
      assert Portfolios.list_portfolios(user.id) == []
    end
  end

  describe "update_portfolio_with_tags/3 with tag allocations" do
    test "persists a changed split", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(
          %{name: "Portfolio", user_id: user.id},
          %{tag1.id => "40", tag2.id => "60"}
        )

      assert {:ok, _} =
               Portfolios.update_portfolio_with_tags(
                 portfolio,
                 %{name: "Portfolio"},
                 %{tag1.id => "30", tag2.id => "70"}
               )

      loaded = Portfolios.load_portfolio_with_tags(portfolio.id)
      percentages = loaded.tags |> Enum.map(&{&1.name, &1.target_allocation_percent}) |> Map.new()

      assert Decimal.equal?(percentages["Growth"], Decimal.new("30"))
      assert Decimal.equal?(percentages["Income"], Decimal.new("70"))
    end

    test "removing a tag from the map deletes its row", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(
          %{name: "Portfolio", user_id: user.id},
          %{tag1.id => "40", tag2.id => "60"}
        )

      assert {:ok, _} =
               Portfolios.update_portfolio_with_tags(
                 portfolio,
                 %{name: "Portfolio"},
                 %{tag1.id => "100"}
               )

      tags = Portfolios.list_tags_for_portfolio(portfolio.id)
      assert Enum.map(tags, & &1.name) == ["Growth"]
    end

    test "a rejected update leaves existing percentages untouched", %{user: user} do
      {:ok, tag1} = Tags.create_tag(%{name: "Growth", user_id: user.id})
      {:ok, tag2} = Tags.create_tag(%{name: "Income", user_id: user.id})

      {:ok, portfolio} =
        Portfolios.create_portfolio_with_tags(
          %{name: "Portfolio", user_id: user.id},
          %{tag1.id => "40", tag2.id => "60"}
        )

      assert {:error, _changeset} =
               Portfolios.update_portfolio_with_tags(
                 portfolio,
                 %{name: "Portfolio"},
                 %{tag1.id => "10", tag2.id => "20"}
               )

      loaded = Portfolios.load_portfolio_with_tags(portfolio.id)
      percentages = loaded.tags |> Enum.map(&{&1.name, &1.target_allocation_percent}) |> Map.new()

      assert Decimal.equal?(percentages["Growth"], Decimal.new("40"))
      assert Decimal.equal?(percentages["Income"], Decimal.new("60"))
    end
  end
end
