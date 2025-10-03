defmodule Boonorbust2Web.UserController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Accounts

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    user = conn.assigns.current_user
    changeset = Accounts.change_user(user)

    if get_req_header(conn, "hx-request") != [] do
      conn
      |> put_layout(false)
      |> render(:edit_modal, user: user, changeset: changeset)
    else
      render(conn, :edit, user: user, changeset: changeset)
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        if get_req_header(conn, "hx-request") != [] do
          # Update the header with new user info
          conn
          |> put_layout(false)
          |> assign(:current_user, updated_user)
          |> render(:header_user_info, user: updated_user)
        else
          redirect(conn, to: ~p"/dashboard")
        end

      {:error, changeset} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_status(:unprocessable_entity)
          |> put_layout(false)
          |> render(:edit_modal, user: user, changeset: changeset)
        else
          render(conn, :edit, user: user, changeset: changeset)
        end
    end
  end
end
