defmodule Boonorbust2.Accounts.User do
  @moduledoc """
  Schema and changeset functions for user accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :uid, :string
    field :provider, :string
    field :email, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :provider, :uid])
    |> validate_required([:email, :name, :provider, :uid])
  end
end
