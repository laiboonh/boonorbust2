defmodule Boonorbust2Web.PortfolioLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Portfolios
  alias Boonorbust2.Portfolios.Portfolio
  alias Boonorbust2.Tags

  @impl true
  def mount(_params, _session, socket) do
    %{id: user_id} = socket.assigns.current_user

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:form_errors, nil)
      |> assign(:portfolio_in_progress, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    %{user_id: user_id} = socket.assigns

    socket =
      socket
      |> assign(:all_tags, Tags.list_tags(user_id))
      |> stream(:portfolios, Portfolios.list_portfolios_with_tags(user_id), reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     assign(socket,
       portfolio_in_progress: %{id: nil, name: nil, description: nil, tags: []},
       form_errors: nil
     )}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    portfolio = Portfolios.load_portfolio_with_tags(String.to_integer(id))
    {:noreply, assign(socket, portfolio_in_progress: portfolio, form_errors: nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, portfolio_in_progress: nil, form_errors: nil)}
  end

  def handle_event("save", %{"portfolio" => portfolio_params} = params, socket) do
    %{user_id: user_id} = socket.assigns
    portfolio_params = Map.put(portfolio_params, "user_id", user_id)
    tag_ids = Map.get(params, "tag_ids", [])

    case Portfolios.create_portfolio_with_tags(portfolio_params, tag_ids) do
      {:ok, portfolio} ->
        socket =
          socket
          |> assign(:portfolio_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:portfolios, Portfolios.load_portfolio_with_tags(portfolio.id))

        {:noreply, socket}

      {:error, changeset} ->
        updated_editing = preserve_user_input(tag_ids, socket.assigns, changeset)

        {:noreply, assign(socket, portfolio_in_progress: updated_editing, form_errors: changeset)}
    end
  end

  def handle_event(
        "update",
        %{"portfolio_id" => id, "portfolio" => portfolio_params} = params,
        socket
      ) do
    portfolio = Portfolios.get_portfolio(String.to_integer(id))
    tag_ids = Map.get(params, "tag_ids", [])

    case Portfolios.update_portfolio_with_tags(portfolio, portfolio_params, tag_ids) do
      {:ok, _updated_portfolio} ->
        socket =
          socket
          |> assign(:portfolio_in_progress, nil)
          |> assign(:form_errors, nil)
          |> stream_insert(:portfolios, Portfolios.load_portfolio_with_tags(portfolio.id))

        {:noreply, socket}

      {:error, changeset} ->
        updated_editing = preserve_user_input(tag_ids, socket.assigns, changeset)

        {:noreply, assign(socket, portfolio_in_progress: updated_editing, form_errors: changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    portfolio_id = String.to_integer(id)
    Portfolios.delete_portfolio_by_id(portfolio_id)

    socket =
      socket
      |> assign(:portfolio_in_progress, nil)
      |> stream_delete(:portfolios, %Portfolio{id: portfolio_id})

    {:noreply, socket}
  end

  def handle_event("delete_tag", %{"id" => id}, socket) do
    %{user_id: user_id} = socket.assigns
    tag = Tags.get_tag!(String.to_integer(id))
    Tags.delete_tag(tag)

    socket =
      socket
      |> assign(:all_tags, Tags.list_tags(user_id))
      |> stream(:portfolios, Portfolios.list_portfolios_with_tags(user_id), reset: true)

    {:noreply, socket}
  end

  # Preserve user's submitted values so the form doesn't reset on error.
  # changeset.changes has the submitted field values; tags are managed
  # separately via tag_ids so we rebuild them from all_tags.
  defp preserve_user_input(tag_ids, assigns, changeset) do
    selected_tags =
      Enum.filter(assigns.all_tags, &(to_string(&1.id) in tag_ids))

    assigns.portfolio_in_progress
    |> Map.merge(changeset.changes)
    |> Map.put(:tags, selected_tags)
  end
end
