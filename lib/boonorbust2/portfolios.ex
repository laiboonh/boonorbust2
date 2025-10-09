defmodule Boonorbust2.Portfolios do
  @moduledoc """
  Context module for managing portfolios and portfolio tags.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Portfolios.Portfolio
  alias Boonorbust2.Portfolios.PortfolioTag
  alias Boonorbust2.Repo
  alias Boonorbust2.Tags.Tag

  # Portfolio functions

  @spec list_portfolios(Ecto.UUID.t()) :: [Portfolio.t()]
  def list_portfolios(user_id) do
    Repo.all(from p in Portfolio, where: p.user_id == ^user_id, order_by: p.name)
  end

  @spec get_portfolio!(integer()) :: Portfolio.t()
  def get_portfolio!(id), do: Repo.get!(Portfolio, id)

  @spec get_portfolio(integer()) :: Portfolio.t() | nil
  def get_portfolio(id), do: Repo.get(Portfolio, id)

  @spec create_portfolio(map()) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def create_portfolio(attrs \\ %{}) do
    %Portfolio{}
    |> Portfolio.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_portfolio(Portfolio.t(), map()) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def update_portfolio(%Portfolio{} = portfolio, attrs) do
    portfolio
    |> Portfolio.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_portfolio(Portfolio.t()) :: {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def delete_portfolio(%Portfolio{} = portfolio) do
    Repo.delete(portfolio)
  end

  @spec change_portfolio(Portfolio.t(), map()) :: Ecto.Changeset.t()
  def change_portfolio(%Portfolio{} = portfolio, attrs \\ %{}) do
    Portfolio.changeset(portfolio, attrs)
  end

  # PortfolioTag functions

  @spec add_tag_to_portfolio(integer(), integer()) ::
          {:ok, PortfolioTag.t()} | {:error, Ecto.Changeset.t()}
  def add_tag_to_portfolio(portfolio_id, tag_id) do
    %PortfolioTag{}
    |> PortfolioTag.changeset(%{
      portfolio_id: portfolio_id,
      tag_id: tag_id
    })
    |> Repo.insert()
  end

  @spec remove_tag_from_portfolio(integer(), integer()) ::
          {:ok, PortfolioTag.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def remove_tag_from_portfolio(portfolio_id, tag_id) do
    portfolio_tag = Repo.get_by(PortfolioTag, portfolio_id: portfolio_id, tag_id: tag_id)

    if portfolio_tag do
      Repo.delete(portfolio_tag)
    else
      {:error, :not_found}
    end
  end

  @spec list_tags_for_portfolio(integer()) :: [Tag.t()]
  def list_tags_for_portfolio(portfolio_id) do
    Repo.all(
      from t in Tag,
        join: pt in PortfolioTag,
        on: pt.tag_id == t.id,
        where: pt.portfolio_id == ^portfolio_id,
        order_by: t.name
    )
  end

  @spec list_portfolios_for_tag(integer()) :: [integer()]
  def list_portfolios_for_tag(tag_id) do
    Repo.all(
      from pt in PortfolioTag,
        where: pt.tag_id == ^tag_id,
        select: pt.portfolio_id
    )
  end
end
