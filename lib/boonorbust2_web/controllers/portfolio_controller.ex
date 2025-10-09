defmodule Boonorbust2Web.PortfolioController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Portfolios
  alias Boonorbust2.Tags

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id} = conn.assigns.current_user
    portfolios = Portfolios.list_portfolios(user_id)
    all_tags = Tags.list_tags()

    # Load tags for each portfolio
    portfolios_with_tags =
      Enum.map(portfolios, fn portfolio ->
        tags = Portfolios.list_tags_for_portfolio(portfolio.id)
        Map.put(portfolio, :tags, tags)
      end)

    render(conn, :index, portfolios: portfolios_with_tags, all_tags: all_tags)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Portfolios.change_portfolio(%Boonorbust2.Portfolios.Portfolio{})
    all_tags = Tags.list_tags()
    render(conn, :new, changeset: changeset, all_tags: all_tags)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"portfolio" => portfolio_params} = params) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_params = Map.put(portfolio_params, "user_id", user_id)

    case Portfolios.create_portfolio(portfolio_params) do
      {:ok, portfolio} ->
        # Handle tag associations
        tag_ids = Map.get(params, "tag_ids", [])

        Enum.each(tag_ids, fn tag_id ->
          tag_id = String.to_integer(tag_id)
          Portfolios.add_tag_to_portfolio(portfolio.id, tag_id)
        end)

        redirect(conn, to: ~p"/portfolios")

      {:error, %Ecto.Changeset{} = changeset} ->
        all_tags = Tags.list_tags()
        render(conn, :new, changeset: changeset, all_tags: all_tags)
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    portfolio = Portfolios.get_portfolio!(id)
    changeset = Portfolios.change_portfolio(portfolio)
    all_tags = Tags.list_tags()
    selected_tags = Portfolios.list_tags_for_portfolio(portfolio.id)
    selected_tag_ids = Enum.map(selected_tags, & &1.id)

    render(conn, :edit,
      portfolio: portfolio,
      changeset: changeset,
      all_tags: all_tags,
      selected_tag_ids: selected_tag_ids
    )
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "portfolio" => portfolio_params} = params) do
    portfolio = Portfolios.get_portfolio!(id)

    case Portfolios.update_portfolio(portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        # Remove all existing tags
        existing_tags = Portfolios.list_tags_for_portfolio(updated_portfolio.id)

        Enum.each(existing_tags, fn tag ->
          Portfolios.remove_tag_from_portfolio(updated_portfolio.id, tag.id)
        end)

        # Add new tags
        tag_ids = Map.get(params, "tag_ids", [])

        Enum.each(tag_ids, fn tag_id ->
          tag_id = String.to_integer(tag_id)
          Portfolios.add_tag_to_portfolio(updated_portfolio.id, tag_id)
        end)

        redirect(conn, to: ~p"/portfolios")

      {:error, %Ecto.Changeset{} = changeset} ->
        all_tags = Tags.list_tags()
        selected_tags = Portfolios.list_tags_for_portfolio(portfolio.id)
        selected_tag_ids = Enum.map(selected_tags, & &1.id)

        render(conn, :edit,
          portfolio: portfolio,
          changeset: changeset,
          all_tags: all_tags,
          selected_tag_ids: selected_tag_ids
        )
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    portfolio = Portfolios.get_portfolio!(id)
    {:ok, _portfolio} = Portfolios.delete_portfolio(portfolio)

    redirect(conn, to: ~p"/portfolios")
  end
end
