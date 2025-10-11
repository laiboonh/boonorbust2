defmodule Boonorbust2.PortfolioSnapshots do
  @moduledoc """
  Context module for managing portfolio snapshots.

  Portfolio snapshots track the total portfolio value for a user on a given date.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.PortfolioSnapshots.PortfolioSnapshot
  alias Boonorbust2.Repo

  @doc """
  Creates or updates a portfolio snapshot for the given user and date.

  Uses upsert logic with the user_id and snapshot_date as the conflict key.
  If a snapshot exists for that user and date, it will be updated.
  Otherwise, a new snapshot will be created.
  """
  @spec upsert_snapshot(String.t(), Date.t(), Money.t()) ::
          {:ok, PortfolioSnapshot.t()} | {:error, Ecto.Changeset.t()}
  def upsert_snapshot(user_id, snapshot_date, total_value) do
    attrs = %{
      user_id: user_id,
      snapshot_date: snapshot_date,
      total_value: total_value
    }

    %PortfolioSnapshot{}
    |> PortfolioSnapshot.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:total_value, :updated_at]},
      conflict_target: [:user_id, :snapshot_date],
      returning: true
    )
  end

  @doc """
  Lists all portfolio snapshots for a given user, ordered by date ascending.

  Options:
    * `:limit` - Maximum number of snapshots to return
    * `:days` - Only return snapshots from the last N days
  """
  @spec list_snapshots(String.t(), keyword()) :: [PortfolioSnapshot.t()]
  def list_snapshots(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    days = Keyword.get(opts, :days)

    query =
      from s in PortfolioSnapshot,
        where: s.user_id == ^user_id,
        order_by: [asc: s.snapshot_date]

    query =
      if days do
        cutoff_date = Date.utc_today() |> Date.add(-days)
        from s in query, where: s.snapshot_date >= ^cutoff_date
      else
        query
      end

    query =
      if limit do
        from s in query, limit: ^limit
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets the latest portfolio snapshot for a given user.
  """
  @spec get_latest_snapshot(String.t()) :: PortfolioSnapshot.t() | nil
  def get_latest_snapshot(user_id) do
    from(s in PortfolioSnapshot,
      where: s.user_id == ^user_id,
      order_by: [desc: s.snapshot_date],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Deletes all snapshots older than the specified number of days.
  """
  @spec delete_old_snapshots(integer()) :: {integer(), nil | [term()]}
  def delete_old_snapshots(days) do
    cutoff_date = Date.utc_today() |> Date.add(-days)

    from(s in PortfolioSnapshot, where: s.snapshot_date < ^cutoff_date)
    |> Repo.delete_all()
  end
end
