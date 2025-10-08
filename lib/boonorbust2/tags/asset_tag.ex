defmodule Boonorbust2.Tags.AssetTag do
  @moduledoc """
  Schema for the many-to-many relationship between assets and tags.
  Each asset_tag belongs to a specific user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Assets.Asset
  alias Boonorbust2.Tags.Tag

  @type t :: %__MODULE__{
          id: integer() | nil,
          asset_id: integer() | nil,
          tag_id: integer() | nil,
          user_id: Ecto.UUID.t() | nil,
          asset: Asset.t() | Ecto.Association.NotLoaded.t() | nil,
          tag: Tag.t() | Ecto.Association.NotLoaded.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "asset_tags" do
    belongs_to :asset, Asset
    belongs_to :tag, Tag
    belongs_to :user, User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(asset_tag, attrs) do
    asset_tag
    |> cast(attrs, [:asset_id, :tag_id, :user_id])
    |> validate_required([:asset_id, :tag_id, :user_id])
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:tag_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:asset_id, :tag_id, :user_id])
  end
end
