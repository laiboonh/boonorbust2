defmodule Boonorbust2.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  use Boonorbust2.RetryWrapper

  alias Boonorbust2.Accounts.User
  alias Boonorbust2.Repo

  @spec get_user_by_id(any()) :: any()
  def get_user_by_id(user_id) do
    Repo.get(Boonorbust2.Accounts.User, user_id)
  end

  @doc """
  Gets a user by email.
  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by provider and uid.
  """
  @spec get_user_by_provider_and_uid(String.t(), String.t()) :: User.t() | nil
  def get_user_by_provider_and_uid(provider, uid) do
    Repo.get_by(User, provider: provider, uid: uid)
  end

  @doc """
  Creates a user from OAuth info.
  """
  @spec create_user_from_oauth(Ueberauth.Auth.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
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
  @spec find_or_create_user(Ueberauth.Auth.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_user(%Ueberauth.Auth{} = auth) do
    case get_user_by_provider_and_uid(to_string(auth.provider), auth.uid) do
      nil ->
        create_user_from_oauth(auth)

      user ->
        {:ok, user}
    end
  end

  @doc """
  Updates a user with given attributes.
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an %Ecto.Changeset{} for tracking user changes.
  """
  @spec change_user(User.t(), map()) :: Ecto.Changeset.t()
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
