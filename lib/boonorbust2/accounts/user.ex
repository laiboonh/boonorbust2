defmodule Boonorbust2.Accounts.User do
  @moduledoc """
  Schema and changeset functions for user accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          uid: String.t() | nil,
          provider: String.t() | nil,
          email: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "users" do
    field :name, :string
    field :uid, :string
    field :provider, :string
    field :email, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :provider, :uid])
    |> validate_required([:email, :name, :provider, :uid])
  end
end
