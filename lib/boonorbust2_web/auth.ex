defmodule Boonorbust2Web.Auth do
  @moduledoc """
  Authentication helper functions for the web application.
  """

  import Plug.Conn

  alias Boonorbust2.Accounts
  alias Boonorbust2.Accounts.User

  @spec init(keyword() | atom()) :: keyword() | atom()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  def call(conn, :require_authenticated_user) do
    require_authenticated_user(conn, [])
  end

  def call(conn, :require_admin) do
    require_admin(conn, [])
  end

  @doc """
  Fetches the current user from the session.
  """
  @spec fetch_current_user(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user_by_id(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Checks if a user is authenticated.
  """
  @spec require_authenticated_user(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  @doc """
  Gets the current user from connection assigns.
  """
  @spec current_user(Plug.Conn.t()) :: User.t() | nil
  def current_user(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Checks if a user is logged in.
  """
  @spec logged_in?(Plug.Conn.t()) :: boolean()
  def logged_in?(conn) do
    !!current_user(conn)
  end

  @doc """
  Checks if the current user is an admin.
  """
  @spec admin?(Plug.Conn.t()) :: boolean()
  def admin?(conn) do
    case current_user(conn) do
      %User{email: email} when is_binary(email) ->
        admin_emails = Application.get_env(:boonorbust2, :admins, [])
        email in admin_emails

      _ ->
        false
    end
  end

  @doc """
  Requires the current user to be an admin.
  Redirects to the dashboard if the user is not an admin.
  """
  @spec require_admin(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def require_admin(conn, _opts) do
    if admin?(conn) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be an admin to access this page.")
      |> Phoenix.Controller.redirect(to: "/dashboard")
      |> halt()
    end
  end
end
