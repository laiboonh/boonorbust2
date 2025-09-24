defmodule HelloWorldWeb.Auth do
  @moduledoc """
  Authentication helper functions for the web application.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  @doc """
  Fetches the current user from the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && HelloWorld.Repo.get(HelloWorld.Accounts.User, user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Checks if a user is authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must log in to access this page.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  @doc """
  Gets the current user from connection assigns.
  """
  def current_user(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Checks if a user is logged in.
  """
  def logged_in?(conn) do
    !!current_user(conn)
  end
end
