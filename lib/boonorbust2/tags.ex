defmodule Boonorbust2.Tags do
  @moduledoc """
  Context module for managing tags and asset tags.
  """
  import Ecto.Query, warn: false

  alias Boonorbust2.Repo
  alias Boonorbust2.Tags.AssetTag
  alias Boonorbust2.Tags.Tag

  # Tag functions

  @spec list_tags() :: [Tag.t()]
  def list_tags do
    Repo.all(from t in Tag, order_by: t.name)
  end

  @spec get_tag!(integer()) :: Tag.t()
  def get_tag!(id), do: Repo.get!(Tag, id)

  @spec get_tag(integer()) :: Tag.t() | nil
  def get_tag(id), do: Repo.get(Tag, id)

  @spec get_tag_by_name(String.t()) :: Tag.t() | nil
  def get_tag_by_name(name), do: Repo.get_by(Tag, name: name)

  @spec create_tag(map()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_tag(Tag.t(), map()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tag(Tag.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @spec change_tag(Tag.t(), map()) :: Ecto.Changeset.t()
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  # AssetTag functions

  @spec add_tag_to_asset(integer(), integer(), Ecto.UUID.t()) ::
          {:ok, AssetTag.t()} | {:error, Ecto.Changeset.t()}
  def add_tag_to_asset(asset_id, tag_id, user_id) do
    %AssetTag{}
    |> AssetTag.changeset(%{
      asset_id: asset_id,
      tag_id: tag_id,
      user_id: user_id
    })
    |> Repo.insert()
  end

  @spec remove_tag_from_asset(integer(), integer(), Ecto.UUID.t()) ::
          {:ok, AssetTag.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def remove_tag_from_asset(asset_id, tag_id, user_id) do
    asset_tag =
      Repo.get_by(AssetTag, asset_id: asset_id, tag_id: tag_id, user_id: user_id)

    if asset_tag do
      Repo.delete(asset_tag)
    else
      {:error, :not_found}
    end
  end

  @spec list_tags_for_asset(integer(), Ecto.UUID.t()) :: [Tag.t()]
  def list_tags_for_asset(asset_id, user_id) do
    Repo.all(
      from t in Tag,
        join: at in AssetTag,
        on: at.tag_id == t.id,
        where: at.asset_id == ^asset_id and at.user_id == ^user_id,
        order_by: t.name
    )
  end

  @spec list_assets_for_tag(integer(), Ecto.UUID.t()) :: [integer()]
  def list_assets_for_tag(tag_id, user_id) do
    Repo.all(
      from at in AssetTag,
        where: at.tag_id == ^tag_id and at.user_id == ^user_id,
        select: at.asset_id
    )
  end

  @spec get_or_create_tag(String.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_tag(name) do
    case get_tag_by_name(name) do
      nil -> create_tag(%{name: name})
      tag -> {:ok, tag}
    end
  end
end
