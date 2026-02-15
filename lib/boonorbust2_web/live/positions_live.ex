defmodule Boonorbust2Web.PositionsLive do
  use Boonorbust2Web, :live_view

  alias Boonorbust2.Assets
  alias Boonorbust2.Dashboard
  alias Boonorbust2.PortfolioPositions
  alias Boonorbust2.RealizedProfits
  alias Boonorbust2.Tags

  @impl true
  def mount(_params, _session, socket) do
    %{id: user_id, currency: user_currency} = socket.assigns.current_user

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:user_currency, user_currency)
      |> assign(:filter, "")
      |> assign(:positions_modal, nil)
      |> assign(:realized_profits_modal, nil)
      |> assign(:tags_modal, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, reload_data(socket)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> reload_data()

    {:noreply, socket}
  end

  def handle_event("clear_filter", _params, socket) do
    socket =
      socket
      |> assign(:filter, "")
      |> reload_data()

    {:noreply, socket}
  end

  def handle_event("show_positions", %{"id" => asset_id}, socket) do
    asset = Assets.get_asset!(asset_id)
    positions = PortfolioPositions.get_positions_for_asset(asset.id, socket.assigns.user_id)

    {:noreply, assign(socket, positions_modal: %{asset: asset, positions: positions})}
  end

  def handle_event("close_positions_modal", _params, socket) do
    {:noreply, assign(socket, positions_modal: nil)}
  end

  def handle_event("show_realized_profits", %{"id" => asset_id}, socket) do
    asset = Assets.get_asset!(asset_id)

    realized_profits =
      RealizedProfits.list_realized_profits_by_asset(asset.id, socket.assigns.user_id)

    total = RealizedProfits.calculate_total(realized_profits)

    {:noreply,
     assign(socket,
       realized_profits_modal: %{
         asset: asset,
         realized_profits: realized_profits,
         total: total
       }
     )}
  end

  def handle_event("close_realized_profits_modal", _params, socket) do
    {:noreply, assign(socket, realized_profits_modal: nil)}
  end

  def handle_event("show_tags", %{"id" => asset_id}, socket) do
    asset = Assets.get_asset!(asset_id)
    tags = Tags.list_tags_for_asset(asset.id, socket.assigns.user_id)

    {:noreply, assign(socket, tags_modal: %{asset: asset, tags: tags})}
  end

  def handle_event("close_tags_modal", _params, socket) do
    {:noreply, assign(socket, tags_modal: nil)}
  end

  def handle_event("add_tag", %{"tag_name" => tag_name}, socket) do
    %{user_id: user_id} = socket.assigns
    asset = socket.assigns.tags_modal.asset

    case Tags.get_or_create_tag(tag_name, user_id) do
      {:ok, tag} ->
        Tags.add_tag_to_asset(asset.id, tag.id)
        tags = Tags.list_tags_for_asset(asset.id, user_id)

        socket =
          socket
          |> assign(:tags_modal, %{asset: asset, tags: tags})
          |> reload_data()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"asset-id" => asset_id, "tag-id" => tag_id}, socket) do
    %{user_id: user_id} = socket.assigns

    Tags.remove_tag_from_asset(String.to_integer(asset_id), String.to_integer(tag_id))

    asset = socket.assigns.tags_modal.asset
    tags = Tags.list_tags_for_asset(asset.id, user_id)

    socket =
      socket
      |> assign(:tags_modal, %{asset: asset, tags: tags})
      |> reload_data()

    {:noreply, socket}
  end

  def position_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1">
          <h3 class="text-base font-semibold text-gray-900">{@position.asset.name}</h3>
        </div>
        <div class="flex items-center gap-1.5">
          <button
            phx-click="show_positions"
            phx-value-id={@position.asset.id}
            class="text-blue-600 hover:text-blue-800"
            title="View positions"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              >
              </path>
            </svg>
          </button>
          <button
            phx-click="show_realized_profits"
            phx-value-id={@position.asset.id}
            class="text-emerald-600 hover:text-emerald-800"
            title="View realized profits"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
          </button>
          <button
            phx-click="show_tags"
            phx-value-id={@position.asset.id}
            class="text-purple-600 hover:text-purple-800"
            title="Manage tags"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
              >
              </path>
            </svg>
          </button>
          <span class="bg-emerald-100 text-emerald-800 text-xs font-medium px-2.5 py-0.5 rounded">
            {String.upcase(@position.portfolio_transaction.action)}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <p class="text-xs text-gray-500">Quantity</p>
          <p class="text-lg font-bold text-gray-900">
            {Decimal.to_string(@position.quantity_on_hand)}
          </p>
        </div>
        <div>
          <p class="text-xs text-gray-500">Avg Price</p>
          <p class="text-lg font-bold text-emerald-600">
            {Money.to_string!(@position.average_price)}
          </p>
        </div>
      </div>

      <div class="mt-3 pt-3 border-t border-gray-200">
        <% converted_cost = Map.get(@position, :converted_total_cost)

        show_converted_cost =
          converted_cost &&
            Money.to_currency_code(converted_cost) !=
              Money.to_currency_code(@position.amount_on_hand) %>
        <div class="flex justify-between items-center mb-2">
          <p class="text-xs text-gray-500">Total Cost</p>
          <div class="text-right">
            <%= if show_converted_cost do %>
              <p class="text-lg font-bold text-gray-900">
                {Money.to_string!(converted_cost)}
              </p>
              <p class="text-xs text-gray-400">
                ({Money.to_string!(@position.amount_on_hand)})
              </p>
            <% else %>
              <p class="text-lg font-bold text-gray-900">
                {Money.to_string!(@position.amount_on_hand)}
              </p>
            <% end %>
          </div>
        </div>
        <%= if @position.asset.price do %>
          <% total_value =
            Money.new!(
              Decimal.mult(@position.quantity_on_hand, @position.asset.price),
              @position.amount_on_hand.currency
            )

          {:ok, unrealized_profit} = Money.sub(total_value, @position.amount_on_hand)

          converted_value = Map.get(@position, :converted_total_value)

          show_converted =
            converted_value &&
              Money.to_currency_code(converted_value) !=
                Money.to_currency_code(total_value) %>
          <div class="flex justify-between items-center">
            <p class="text-xs text-gray-500">Total Value</p>
            <div class="text-right">
              <%= if show_converted do %>
                <p class="text-xl font-bold text-emerald-600">
                  {Money.to_string!(converted_value)}
                </p>
                <p class="text-xs text-gray-400">
                  ({Money.to_string!(total_value)})
                </p>
              <% else %>
                <p class="text-xl font-bold text-emerald-600">
                  {Money.to_string!(total_value)}
                </p>
              <% end %>
            </div>
          </div>
          <% converted_unrealized_profit = Map.get(@position, :converted_unrealized_profit)

          show_converted_unrealized =
            converted_unrealized_profit &&
              Money.to_currency_code(converted_unrealized_profit) !=
                Money.to_currency_code(unrealized_profit) %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Unrealized Profit</p>
            <div class="text-right">
              <%= if show_converted_unrealized do %>
                <p class={[
                  "text-base font-bold",
                  if(Decimal.positive?(converted_unrealized_profit.amount),
                    do: "text-emerald-600",
                    else: "text-red-600"
                  )
                ]}>
                  {Money.to_string!(converted_unrealized_profit)}
                </p>
                <p class="text-xs text-gray-400">
                  ({Money.to_string!(unrealized_profit)})
                </p>
              <% else %>
                <p class={[
                  "text-base font-bold",
                  if(Decimal.positive?(unrealized_profit.amount),
                    do: "text-emerald-600",
                    else: "text-red-600"
                  )
                ]}>
                  {Money.to_string!(unrealized_profit)}
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
        <%= if !Decimal.equal?(@capital_gains.amount, 0) do %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Capital Gains</p>
            <div class="text-right">
              <p class={[
                "text-base font-bold",
                if(Decimal.positive?(@capital_gains.amount),
                  do: "text-emerald-600",
                  else: "text-red-600"
                )
              ]}>
                {Money.to_string!(@capital_gains)}
              </p>
            </div>
          </div>
        <% end %>
        <%= if !Decimal.equal?(@dividend_income.amount, 0) do %>
          <div class="flex justify-between items-center mt-2 pt-2 border-t border-gray-100">
            <p class="text-xs text-gray-500">Dividend Income</p>
            <div class="text-right">
              <p class="text-base font-bold text-emerald-600">
                {Money.to_string!(@dividend_income)}
              </p>
            </div>
          </div>
        <% end %>
      </div>

      <p class="text-xs text-gray-400 mt-3">
        Last updated: {Calendar.strftime(
          @position.portfolio_transaction.transaction_date,
          "%B %d, %Y"
        )}
      </p>

      <% tags = Map.get(@position, :tags, []) %>
      <%= if tags && !Enum.empty?(tags) do %>
        <div class="mt-3 flex flex-wrap gap-2">
          <%= for tag <- tags do %>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              {tag.name}
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp reload_data(socket) do
    %{user_id: user_id, user_currency: user_currency, filter: filter} = socket.assigns

    positions = PortfolioPositions.list_latest_positions(user_id, filter)
    realized_profits_by_asset = RealizedProfits.get_totals_by_asset(user_id)
    realized_profits_by_type = RealizedProfits.get_totals_by_asset_and_type(user_id)

    enriched_positions =
      Dashboard.enrich_positions_for_dashboard(positions, user_id, user_currency)

    converted_realized_profits_by_asset =
      Dashboard.convert_realized_profits_by_asset(realized_profits_by_asset, user_currency)

    converted_realized_profits_by_type =
      Dashboard.convert_realized_profits_by_type(realized_profits_by_type, user_currency)

    assign(socket,
      positions: enriched_positions,
      realized_profits_by_asset: realized_profits_by_asset,
      converted_realized_profits_by_asset: converted_realized_profits_by_asset,
      converted_realized_profits_by_type: converted_realized_profits_by_type
    )
  end
end
