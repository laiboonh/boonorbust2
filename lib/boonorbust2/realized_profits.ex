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

  @doc """
  Calculates the total realized profit from a list of realized profits.
  Returns the sum of all amounts.
  """
  @spec calculate_total([RealizedProfit.t()]) :: Money.t()
  def calculate_total([]), do: Money.new(:SGD, 0)

  def calculate_total([first | rest]) do
    Enum.reduce(rest, first.amount, fn rp, acc ->
      {:ok, sum} = Money.add(acc, rp.amount)
      sum
    end)
  end

  @doc """
  Calculates the total realized profit for a user across all assets.
  """
  @spec calculate_total_by_user(String.t()) :: Money.t()
  def calculate_total_by_user(user_id) do
    user_id
    |> list_realized_profits_by_user()
    |> calculate_total()
  end

  @doc """
  Returns a map of asset_id => total realized profit for all assets owned by a user.
  """
  @spec get_totals_by_asset(String.t()) :: %{integer() => Money.t()}
  def get_totals_by_asset(user_id) do
    user_id
    |> list_realized_profits_by_user()
    |> Enum.group_by(& &1.asset_id)
    |> Map.new(fn {asset_id, profits} ->
      {asset_id, calculate_total(profits)}
    end)
  end
end
