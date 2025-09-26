defmodule Boonorbust2Web.MessageController do
  use Boonorbust2Web, :controller

  import Ecto.Query

  alias Boonorbust2.Messages.Message
  alias Boonorbust2.Repo
  alias Helper

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    messages =
      Helper.do_retry(Boonorbust2.Messages, :get_all, [], [
        DBConnection.ConnectionError
      ])

    render(conn, :index, messages: messages)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"message" => message_params}) do
    changeset = Message.changeset(%Message{}, message_params)

    case Repo.insert(changeset) do
      {:ok, message} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:message_item, message: message)
        else
          conn
          |> redirect(to: ~p"/messages")
        end

      {:error, changeset} ->
        messages = Repo.all(from m in Message, order_by: [desc: m.inserted_at])
        render(conn, :index, messages: messages, changeset: changeset)
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "message" => message_params}) do
    message = Repo.get!(Message, id)
    changeset = Message.changeset(message, message_params)

    case Repo.update(changeset) do
      {:ok, updated_message} ->
        if get_req_header(conn, "hx-request") != [] do
          conn
          |> put_layout(false)
          |> render(:message_item, message: updated_message)
        else
          conn
          |> redirect(to: ~p"/messages")
        end

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:message_item, message: message)
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    message = Repo.get!(Message, id)
    Repo.delete!(message)

    if get_req_header(conn, "hx-request") != [] do
      send_resp(conn, 200, "")
    else
      conn
      |> redirect(to: ~p"/messages")
    end
  end
end
