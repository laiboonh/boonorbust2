defmodule HelloWorld.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias HelloWorld.Repo
  alias HelloWorld.Accounts.User

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by provider and uid.
  """
  def get_user_by_provider_and_uid(provider, uid) do
    Repo.get_by(User, provider: provider, uid: uid)
  end

  @doc """
  Creates a user from OAuth info.
  """
  def create_user_from_oauth(%Ueberauth.Auth{} = auth) do
    attrs = %{
      email: auth.info.email,
      name: auth.info.name,
      provider: to_string(auth.provider),
      uid: auth.uid
    }

    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds or creates a user from OAuth info.
  """
  def find_or_create_user(%Ueberauth.Auth{} = auth) do
    case get_user_by_provider_and_uid(to_string(auth.provider), auth.uid) do
      nil ->
        create_user_from_oauth(auth)
      user ->
        {:ok, user}
    end
  end
end