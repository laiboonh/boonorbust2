defmodule Boonorbust2Web.PortfolioController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Portfolios
  alias Boonorbust2.Portfolios.Portfolio
  alias Boonorbust2.Tags

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    %{id: user_id} = conn.assigns.current_user

    # Delegate data enrichment to context
    portfolios_with_tags = Portfolios.list_portfolios_with_tags(user_id)
    all_tags = Tags.list_tags(user_id)

    render(conn, :index, portfolios: portfolios_with_tags, all_tags: all_tags)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    %{id: user_id} = conn.assigns.current_user
    changeset = Portfolios.change_portfolio(%Portfolio{})
    all_tags = Tags.list_tags(user_id)
    render(conn, :new, changeset: changeset, all_tags: all_tags)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"portfolio" => portfolio_params} = params) do
    %{id: user_id} = conn.assigns.current_user
    portfolio_params = Map.put(portfolio_params, "user_id", user_id)
    tag_ids = Map.get(params, "tag_ids", [])

    # Delegate to atomic context operation
    case Portfolios.create_portfolio_with_tags(portfolio_params, tag_ids) do
      {:ok, _portfolio} ->
        redirect(conn, to: ~p"/portfolios")

      {:error, %Ecto.Changeset{} = changeset} ->
        all_tags = Tags.list_tags(user_id)
        render(conn, :new, changeset: changeset, all_tags: all_tags)

      {:error, :tag_association_failed} ->
        all_tags = Tags.list_tags(user_id)

        changeset =
          %Portfolio{}
          |> Portfolio.changeset(portfolio_params)
          |> Ecto.Changeset.add_error(:base, "Failed to associate tags")

        render(conn, :new, changeset: changeset, all_tags: all_tags)
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    %{id: user_id} = conn.assigns.current_user
    portfolio = Portfolios.get_portfolio!(id)
    changeset = Portfolios.change_portfolio(portfolio)
    all_tags = Tags.list_tags(user_id)

    # Delegate tag ID extraction to context
    selected_tag_ids = Portfolios.list_tag_ids_for_portfolio(portfolio.id)

    render(conn, :edit,
      portfolio: portfolio,
      changeset: changeset,
      all_tags: all_tags,
      selected_tag_ids: selected_tag_ids
    )
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "portfolio" => portfolio_params} = params) do
    %{id: user_id} = conn.assigns.current_user
    portfolio = Portfolios.get_portfolio!(id)
    tag_ids = Map.get(params, "tag_ids", [])

    # Delegate to atomic context operation
    case Portfolios.update_portfolio_with_tags(portfolio, portfolio_params, tag_ids) do
      {:ok, _updated_portfolio} ->
        redirect(conn, to: ~p"/portfolios")

      {:error, %Ecto.Changeset{} = changeset} ->
        all_tags = Tags.list_tags(user_id)
        selected_tag_ids = Portfolios.list_tag_ids_for_portfolio(portfolio.id)

        render(conn, :edit,
          portfolio: portfolio,
          changeset: changeset,
          all_tags: all_tags,
          selected_tag_ids: selected_tag_ids
        )

      {:error, :tag_sync_failed} ->
        all_tags = Tags.list_tags(user_id)
        selected_tag_ids = Portfolios.list_tag_ids_for_portfolio(portfolio.id)

        changeset =
          portfolio
          |> Portfolio.changeset(portfolio_params)
          |> Ecto.Changeset.add_error(:base, "Failed to synchronize tags")

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
