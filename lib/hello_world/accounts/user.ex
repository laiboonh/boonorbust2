defmodule HelloWorld.Accounts.User do
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
