defmodule Boonorbust2.RealizedProfits do
  @moduledoc """
  Context module for managing realized profits.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.RealizedProfits.RealizedProfit
  alias Boonorbust2.Repo

  @spec upsert_realized_profit(map()) ::
          {:ok, RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  def upsert_realized_profit(attrs) do
    %RealizedProfit{}
    |> RealizedProfit.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:amount, :updated_at]},
      conflict_target: :portfolio_transaction_id
    )
  end

  @spec get_realized_profit_by_transaction(integer()) :: RealizedProfit.t() | nil
  def get_realized_profit_by_transaction(portfolio_transaction_id) do
    from(rp in RealizedProfit,
      where: rp.portfolio_transaction_id == ^portfolio_transaction_id
    )
    |> Repo.one()
  end

  @spec list_realized_profits_by_user(String.t()) :: [RealizedProfit.t()]
  def list_realized_profits_by_user(user_id) do
    from(rp in RealizedProfit,
      where: rp.user_id == ^user_id,
      order_by: [desc: rp.inserted_at],
      preload: [:asset, :portfolio_transaction]
    )
    |> Repo.all()
  end

  @spec list_realized_profits_by_asset(integer(), String.t()) :: [RealizedProfit.t()]
  def list_realized_profits_by_asset(asset_id, user_id) do
    from(rp in RealizedProfit,
      where: rp.asset_id == ^asset_id and rp.user_id == ^user_id,
      order_by: [desc: rp.inserted_at],
      preload: [:portfolio_transaction]
    )
    |> Repo.all()
  end

  @spec delete_realized_profit(RealizedProfit.t()) ::
          {:ok, RealizedProfit.t()} | {:error, Ecto.Changeset.t()}
  def delete_realized_profit(%RealizedProfit{} = realized_profit) do
    Repo.delete(realized_profit)
  end
end
