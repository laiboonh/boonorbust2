defmodule Boonorbust2Web.TagController do
  use Boonorbust2Web, :controller

  alias Boonorbust2.Tags

  require Logger

  @spec add_tag_to_asset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_tag_to_asset(conn, params) do
    %{id: user_id} = conn.assigns.current_user
    asset_id = parse_asset_id(params)
    tag_name = params["tag_name"]

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
  def remove_tag_from_asset(conn, params) do
    %{id: user_id} = conn.assigns.current_user
    asset_id = parse_asset_id(params)
    tag_id = parse_tag_id(params)

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

  # Private functions

  @spec parse_asset_id(map()) :: integer()
  defp parse_asset_id(%{"asset_id" => asset_id}) do
    case Integer.parse(asset_id) do
      {num, _} when num > 0 -> num
      _ -> raise "Invalid asset_id"
    end
  end

  @spec parse_tag_id(map()) :: integer()
  defp parse_tag_id(%{"tag_id" => tag_id}) do
    case Integer.parse(tag_id) do
      {num, _} when num > 0 -> num
      _ -> raise "Invalid tag_id"
    end
  end
end
