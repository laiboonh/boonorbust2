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

  @spec get_portfolio(integer()) :: Portfolio.t() | nil
  def get_portfolio(id), do: Repo.get(Portfolio, id)

  @doc """
  Deletes a portfolio by ID, including its associated portfolio tags.
  """
  @spec delete_portfolio_by_id(integer()) :: :ok
  def delete_portfolio_by_id(id) do
    tags_query = from(pt in PortfolioTag, where: pt.portfolio_id == ^id)
    portfolio_query = from(p in Portfolio, where: p.id == ^id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:tags, tags_query)
    |> Ecto.Multi.delete_all(:portfolio, portfolio_query)
    |> Repo.transaction()

    :ok
  end

  @doc """
  Lists all portfolios for a user with their associated tags in a single query.
  """
  @spec list_portfolios_with_tags(Ecto.UUID.t()) :: [map()]
  def list_portfolios_with_tags(user_id) do
    query =
      from p in Portfolio,
        left_join: pt in PortfolioTag,
        on: pt.portfolio_id == p.id,
        left_join: t in Tag,
        on: t.id == pt.tag_id,
        where: p.user_id == ^user_id,
        order_by: [asc: p.name, asc: t.name],
        select: {p, t}

    query
    |> Repo.all()
    |> Enum.group_by(fn {portfolio, _tag} -> portfolio end, fn {_portfolio, tag} -> tag end)
    |> Enum.map(fn {portfolio, tags} ->
      Map.put(portfolio, :tags, Enum.filter(tags, & &1))
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Loads a single portfolio with its tags preloaded.
  """
  @spec load_portfolio_with_tags(integer()) :: map()
  def load_portfolio_with_tags(portfolio_id) do
    query =
      from p in Portfolio,
        left_join: pt in PortfolioTag,
        on: pt.portfolio_id == p.id,
        left_join: t in Tag,
        on: t.id == pt.tag_id,
        where: p.id == ^portfolio_id,
        order_by: [asc: t.name],
        select: {p, t}

    query
    |> Repo.all()
    |> case do
      [] ->
        get_portfolio(portfolio_id) |> Map.put(:tags, [])

      results ->
        {portfolio, _} = hd(results)
        tags = results |> Enum.map(fn {_, tag} -> tag end) |> Enum.filter(& &1)
        Map.put(portfolio, :tags, tags)
    end
  end

  @doc """
  Creates a portfolio with associated tags in an atomic transaction.
  Returns the portfolio with tags preloaded.
  """
  @spec create_portfolio_with_tags(map(), [String.t()] | [integer()]) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def create_portfolio_with_tags(attrs, tag_ids \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:portfolio, Portfolio.changeset(%Portfolio{}, attrs))
    |> Ecto.Multi.run(:tags, fn repo, %{portfolio: portfolio} ->
      insert_portfolio_tags(repo, portfolio.id, tag_ids)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{portfolio: portfolio}} ->
        {:ok, portfolio}

      {:error, :portfolio, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a portfolio and synchronizes its tags in an atomic transaction.
  Removes all existing tags and replaces with the provided tag_ids.
  """
  @spec update_portfolio_with_tags(Portfolio.t(), map(), [String.t()] | [integer()]) ::
          {:ok, Portfolio.t()} | {:error, Ecto.Changeset.t()}
  def update_portfolio_with_tags(%Portfolio{} = portfolio, attrs, tag_ids \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:portfolio, Portfolio.changeset(portfolio, attrs))
    |> Ecto.Multi.run(:remove_tags, fn repo, %{portfolio: updated_portfolio} ->
      {_count, _} =
        repo.delete_all(
          from pt in PortfolioTag,
            where: pt.portfolio_id == ^updated_portfolio.id
        )

      {:ok, true}
    end)
    |> Ecto.Multi.run(:add_tags, fn repo, %{portfolio: updated_portfolio} ->
      insert_portfolio_tags(repo, updated_portfolio.id, tag_ids)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{portfolio: portfolio}} ->
        {:ok, portfolio}

      {:error, :portfolio, changeset, _} ->
        {:error, changeset}
    end
  end

  # PortfolioTag functions

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

  # Private helpers

  # Helper for string/integer normalization
  defp normalize_tag_ids(tag_ids) do
    Enum.map(tag_ids, fn
      id when is_binary(id) -> String.to_integer(id)
      id when is_integer(id) -> id
    end)
  end

  # Helper to insert portfolio tags in bulk
  defp insert_portfolio_tags(repo, portfolio_id, tag_ids) do
    normalized_tag_ids = normalize_tag_ids(tag_ids)

    if normalized_tag_ids == [] do
      {:ok, []}
    else
      do_insert_portfolio_tags(repo, portfolio_id, normalized_tag_ids)
    end
  end

  defp do_insert_portfolio_tags(repo, portfolio_id, normalized_tag_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    portfolio_tags =
      Enum.map(normalized_tag_ids, fn tag_id ->
        %{
          portfolio_id: portfolio_id,
          tag_id: tag_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    {_count, _} = repo.insert_all(PortfolioTag, portfolio_tags)
    {:ok, true}
  end
end
