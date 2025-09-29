defmodule Boonorbust2Web.Auth do
  @moduledoc """
  Authentication helper functions for the web application.
  """

  import Plug.Conn

  alias Boonorbust2.Accounts
  alias Boonorbust2.Accounts.User

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  def call(conn, :require_authenticated_user) do
    require_authenticated_user(conn, [])
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
end
