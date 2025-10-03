defmodule Boonorbust2Web.DashboardHTML do
  use Boonorbust2Web, :html

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <h1 class="text-2xl font-bold text-gray-900 mb-6">Portfolio Dashboard</h1>

          <%= if Enum.empty?(@positions) do %>
            <div class="bg-white rounded-lg shadow p-8 text-center">
              <p class="text-gray-500 mb-4">No portfolio positions yet.</p>
              <p class="text-sm text-gray-400">
                Add transactions to see your portfolio positions here.
              </p>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for position <- @positions do %>
                <.position_card position={position} />
              <% end %>
            </div>
          <% end %>
        </div>

        <.tab_bar current_tab="dashboard">
          <:tab navigate={~p"/dashboard"} name="dashboard" icon="hero-home">
            Dashboard
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-chart-bar">
            Assets
          </:tab>
          <:tab navigate={~p"/portfolio_transactions"} name="portfolio" icon="hero-document-text">
            Transactions
          </:tab>
        </.tab_bar>
      </div>
    </.tab_content>
    """
  end

  def position_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">{@position.asset.name}</h3>
          <span class="text-sm text-gray-500">{@position.asset.code}</span>
        </div>
        <span class="bg-emerald-100 text-emerald-800 text-xs font-medium px-2.5 py-0.5 rounded">
          {String.upcase(@position.portfolio_transaction.action)}
        </span>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-sm text-gray-500">Quantity</p>
          <p class="text-xl font-bold text-gray-900">
            {Decimal.to_string(@position.quantity_on_hand)}
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-500">Avg Price</p>
          <p class="text-xl font-bold text-emerald-600">
            {Money.to_string!(@position.average_price)}
          </p>
        </div>
      </div>

      <div class="mt-4 pt-4 border-t border-gray-200">
        <div class="flex justify-between items-center">
          <p class="text-sm text-gray-500">Total Value</p>
          <p class="text-2xl font-bold text-emerald-600">
            {Money.to_string!(@position.amount_on_hand)}
          </p>
        </div>
      </div>

      <p class="text-xs text-gray-400 mt-4">
        Last updated: {Calendar.strftime(
          @position.portfolio_transaction.transaction_date,
          "%B %d, %Y"
        )}
      </p>
    </div>
    """
  end
end
