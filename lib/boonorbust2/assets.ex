defmodule Boonorbust2.Assets do
  @moduledoc """
  Context module for managing assets.
  """
  import Ecto.Query, warn: false

  use Boonorbust2.RetryWrapper

  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Repo

  @spec list_assets() :: [Asset.t()]
  def list_assets do
    Repo.all(from a in Asset, order_by: a.name)
  end

  @spec get_asset!(integer()) :: Asset.t()
  def get_asset!(id), do: Repo.get!(Asset, id)

  @spec get_asset(integer()) :: Asset.t() | nil
  def get_asset(id), do: Repo.get(Asset, id)

  @spec get_asset_by_code(String.t()) :: Asset.t() | nil
  def get_asset_by_code(code), do: Repo.get_by(Asset, code: code)

  @spec create_asset(map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def create_asset(attrs \\ %{}) do
    %Asset{}
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) do
    asset
    |> Asset.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_asset(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def delete_asset(%Asset{} = asset) do
    Repo.delete(asset)
  end

  @spec change_asset(Asset.t(), map()) :: Ecto.Changeset.t()
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end
end
