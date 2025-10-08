defmodule Boonorbust2.Tags.Tag do
  @moduledoc """
  Schema and changeset functions for tags.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Boonorbust2.Tags.AssetTag

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          color: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "tags" do
    field :name, :string
    field :color, :string

    has_many :asset_tags, AssetTag

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
