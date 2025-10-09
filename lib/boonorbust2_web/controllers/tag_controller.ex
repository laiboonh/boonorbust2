defmodule Boonorbust2Web.TagController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Tags

  require Logger

  @spec add_tag_to_asset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_tag_to_asset(conn, %{"asset_id" => asset_id, "tag_name" => tag_name}) do
    %{id: user_id} = conn.assigns.current_user
    asset_id = String.to_integer(asset_id)

    case Tags.get_or_create_tag(tag_name, user_id) do
      {:ok, tag} ->
        case Tags.add_tag_to_asset(asset_id, tag.id) do
          {:ok, _asset_tag} ->
            tags = Tags.list_tags_for_asset(asset_id, user_id)

            conn
            |> put_layout(false)
            |> render(:tags_list, asset_id: asset_id, tags: tags)

          {:error, changeset} ->
            Logger.warning("Failed to add tag to asset: #{inspect(changeset)}")

            conn
            |> put_status(:unprocessable_entity)
            |> put_layout(false)
            |> render(:error, message: "Failed to add tag")
        end

      {:error, changeset} ->
        Logger.warning("Failed to create tag: #{inspect(changeset)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_layout(false)
        |> render(:error, message: "Failed to create tag")
    end
  end

  @spec remove_tag_from_asset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_tag_from_asset(conn, %{"asset_id" => asset_id, "tag_id" => tag_id}) do
    %{id: user_id} = conn.assigns.current_user
    asset_id = String.to_integer(asset_id)
    tag_id = String.to_integer(tag_id)

    case Tags.remove_tag_from_asset(asset_id, tag_id) do
      {:ok, _asset_tag} ->
        tags = Tags.list_tags_for_asset(asset_id, user_id)

        conn
        |> put_layout(false)
        |> render(:tags_list, asset_id: asset_id, tags: tags)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_layout(false)
        |> render(:error, message: "Tag not found")

      {:error, changeset} ->
        Logger.warning("Failed to remove tag from asset: #{inspect(changeset)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_layout(false)
        |> render(:error, message: "Failed to remove tag")
    end
  end
end
