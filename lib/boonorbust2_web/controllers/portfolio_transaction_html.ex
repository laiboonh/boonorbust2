defmodule Boonorbust2Web.PortfolioTransactionHTML do
  use Boonorbust2Web, :html

  alias Boonorbust2.Currency

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="flex gap-3 mb-6">
            <button
              onclick="document.getElementById('csv-upload-modal').classList.remove('hidden')"
              class="flex-1 inline-flex justify-center items-center px-4 py-3 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                />
              </svg>
              Import CSV
            </button>

            <button
              onclick="document.getElementById('portfolio-transaction-modal').classList.remove('hidden')"
              class="flex-1 inline-flex justify-center items-center px-4 py-3 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-emerald-500"
            >
              <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                />
              </svg>
              Add Transaction
            </button>
          </div>
          
    <!-- Filter Form -->
          <form method="get" action={~p"/portfolio_transactions"} class="mb-4">
            <div class="flex gap-2">
              <input
                type="text"
                name="filter"
                value={@filter}
                placeholder="Search by asset name..."
                class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <button
                type="submit"
                class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-emerald-500"
              >
                Filter
              </button>
              <%= if @filter != "" do %>
                <a
                  href={~p"/portfolio_transactions"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Clear
                </a>
              <% end %>
            </div>
          </form>
          
    <!-- Portfolio Transactions List -->
          <div id="portfolio-transactions-list" class="space-y-4">
            <%= for portfolio_transaction <- @portfolio_transactions do %>
              <.portfolio_transaction_item portfolio_transaction={portfolio_transaction} />
            <% end %>
          </div>
          
    <!-- Pagination -->
          <%= if @total_pages > 1 do %>
            <div class="mt-6 flex justify-center items-center gap-2">
              <%= if @page_number > 1 do %>
                <a
                  href={
                    if @filter != "",
                      do: ~p"/portfolio_transactions?page=#{@page_number - 1}&filter=#{@filter}",
                      else: ~p"/portfolio_transactions?page=#{@page_number - 1}"
                  }
                  class="px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Previous
                </a>
              <% else %>
                <span class="px-3 py-2 text-sm font-medium text-gray-400 bg-gray-100 border border-gray-300 rounded-md cursor-not-allowed">
                  Previous
                </span>
              <% end %>

              <span class="px-4 py-2 text-sm text-gray-700">
                Page {@page_number} of {@total_pages}
              </span>

              <%= if @page_number < @total_pages do %>
                <a
                  href={
                    if @filter != "",
                      do: ~p"/portfolio_transactions?page=#{@page_number + 1}&filter=#{@filter}",
                      else: ~p"/portfolio_transactions?page=#{@page_number + 1}"
                  }
                  class="px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Next
                </a>
              <% else %>
                <span class="px-3 py-2 text-sm font-medium text-gray-400 bg-gray-100 border border-gray-300 rounded-md cursor-not-allowed">
                  Next
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Portfolio Transaction Modal -->
        <div
          id="portfolio-transaction-modal"
          class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        >
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-gray-900">Add New Transaction</h3>
                <button
                  onclick="document.getElementById('portfolio-transaction-modal').classList.add('hidden')"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    >
                    </path>
                  </svg>
                </button>
              </div>

              <div id="portfolio-transaction-form-errors"></div>

              <div class="relative">
                <!-- Loading overlay -->
                <div
                  id="portfolio-transaction-form-overlay"
                  class="htmx-indicator absolute inset-0 bg-gray-100 bg-opacity-75 flex items-center justify-center rounded-lg z-10"
                >
                  <div class="text-center">
                    <svg
                      class="h-8 w-8 animate-spin text-emerald-600 mx-auto mb-2"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    <p class="text-sm text-gray-700">Saving transaction...</p>
                  </div>
                </div>

                <form
                  action={~p"/portfolio_transactions"}
                  method="post"
                  id="portfolio-transaction-form"
                  hx-post={~p"/portfolio_transactions"}
                  hx-target="#portfolio-transactions-list"
                  hx-swap="afterbegin"
                  hx-indicator="#portfolio-transaction-form-overlay"
                  hx-on--response-error="document.getElementById('portfolio-transaction-form-errors').innerHTML = event.detail.xhr.responseText;"
                  hx-on--after-request="if(event.detail.xhr.status >= 200 && event.detail.xhr.status < 300) { document.getElementById('portfolio-transaction-form').reset(); document.getElementById('portfolio-transaction-modal').classList.add('hidden'); document.getElementById('portfolio-transaction-form-errors').innerHTML = ''; }"
                  class="space-y-4"
                >
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

                  <div>
                    <label
                      for="portfolio_transaction_asset_id"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Asset
                    </label>
                    <select
                      id="portfolio_transaction_asset_id"
                      name="portfolio_transaction[asset_id]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <option value="">Select an asset</option>
                      <%= for asset <- Boonorbust2.Assets.list_assets() do %>
                        <option value={asset.id}>{asset.name}</option>
                      <% end %>
                    </select>
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_action"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Action
                    </label>
                    <select
                      id="portfolio_transaction_action"
                      name="portfolio_transaction[action]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <option value="">Select action</option>
                      <option value="buy">Buy</option>
                      <option value="sell">Sell</option>
                    </select>
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_quantity"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Quantity
                    </label>
                    <input
                      type="number"
                      step="any"
                      min="0"
                      id="portfolio_transaction_quantity"
                      name="portfolio_transaction[quantity]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. 1000"
                    />
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_currency"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Currency
                    </label>
                    <select
                      id="portfolio_transaction_currency"
                      name="portfolio_transaction[currency]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <%= for currency <- Currency.supported_currencies() do %>
                        <option value={currency} selected={currency == Currency.default_currency()}>
                          {currency}
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_price"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Price per Share
                    </label>
                    <input
                      type="number"
                      step="any"
                      min="0"
                      id="portfolio_transaction_price"
                      name="portfolio_transaction[price]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. 1.50"
                    />
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_commission"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Commission
                    </label>
                    <input
                      type="number"
                      step="any"
                      min="0"
                      id="portfolio_transaction_commission"
                      name="portfolio_transaction[commission]"
                      required
                      value="0"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      placeholder="e.g. 5.00"
                    />
                  </div>

                  <div>
                    <label
                      for="portfolio_transaction_transaction_date"
                      class="block text-sm font-medium text-gray-700"
                    >
                      Transaction Date
                    </label>
                    <input
                      type="datetime-local"
                      id="portfolio_transaction_transaction_date"
                      name="portfolio_transaction[transaction_date]"
                      required
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    />
                  </div>

                  <div class="flex gap-3 pt-4">
                    <button
                      type="submit"
                      class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
                    >
                      Add Transaction
                    </button>
                    <button
                      type="button"
                      onclick="document.getElementById('portfolio-transaction-modal').classList.add('hidden')"
                      class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
        
    <!-- CSV Upload Modal -->
        <div
          id="csv-upload-modal"
          class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        >
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-medium text-gray-900">Import CSV File</h3>
                <button
                  onclick="document.getElementById('csv-upload-modal').classList.add('hidden')"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    >
                    </path>
                  </svg>
                </button>
              </div>

              <div id="csv-upload-errors"></div>
              <div
                id="csv-upload-success"
                class="hidden mb-4 p-3 bg-green-100 border border-green-400 text-green-700 rounded"
              >
              </div>

              <form
                action={~p"/portfolio_transactions/import_csv"}
                method="post"
                id="csv-upload-form"
                enctype="multipart/form-data"
                hx-post={~p"/portfolio_transactions/import_csv"}
                hx-encoding="multipart/form-data"
                hx-target="#csv-upload-success"
                hx-swap="innerHTML"
                hx-on--response-error="document.getElementById('csv-upload-errors').innerHTML = event.detail.xhr.responseText;"
                hx-on--after-request="if(event.detail.xhr.status >= 200 && event.detail.xhr.status < 300) { document.getElementById('csv-upload-form').reset(); document.getElementById('csv-upload-success').classList.remove('hidden'); document.getElementById('csv-upload-errors').innerHTML = ''; setTimeout(() => { document.getElementById('csv-upload-modal').classList.add('hidden'); document.getElementById('csv-upload-success').classList.add('hidden'); location.reload(); }, 2000); }"
                class="space-y-4"
              >
                <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

                <div>
                  <label for="csv_file" class="block text-sm font-medium text-gray-700 mb-2">
                    Select CSV File
                  </label>
                  <input
                    type="file"
                    id="csv_file"
                    name="csv_file"
                    accept=".csv"
                    required
                    class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-emerald-50 file:text-emerald-700 hover:file:bg-emerald-100"
                  />
                </div>

                <div class="text-sm text-gray-600">
                  <p class="font-medium mb-1">CSV Format Requirements:</p>
                  <ul class="text-xs space-y-1">
                    <li>• Stock, Action, Quantity, Price, Commission, Date, Currency</li>
                    <li>• Date format: DD MMM YYYY (e.g. 26 Jul 2023)</li>
                    <li>• Action: buy or sell</li>
                    <li>• Currency: {Enum.join(Currency.supported_currencies(), ", ")}</li>
                    <li class="text-gray-500 italic">
                      • Amount is calculated automatically (quantity × price + commission)
                    </li>
                  </ul>
                </div>

                <div class="flex gap-3 pt-4">
                  <button
                    type="submit"
                    class="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  >
                    Import CSV
                  </button>
                  <button
                    type="button"
                    onclick="document.getElementById('csv-upload-modal').classList.add('hidden')"
                    class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <.tab_bar current_tab="transactions">
          <:tab navigate={~p"/dashboard"} name="dashboard" icon="hero-home">
            Dashboard
          </:tab>
          <:tab navigate={~p"/positions"} name="positions" icon="hero-chart-bar">
            Positions
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-squares-2x2">
            Assets
          </:tab>
          <:tab navigate={~p"/portfolio_transactions"} name="transactions" icon="hero-document-text">
            Transactions
          </:tab>
          <:tab navigate={~p"/portfolios"} name="portfolios" icon="hero-folder">
            Portfolios
          </:tab>
        </.tab_bar>
      </div>
    </.tab_content>
    """
  end

  def portfolio_transaction_item(assigns) do
    ~H"""
    <div
      id={"portfolio-transaction-#{@portfolio_transaction.id}"}
      class="bg-white rounded-lg shadow p-4"
    >
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div id={"portfolio-transaction-view-#{@portfolio_transaction.id}"}>
            <div class="flex justify-between items-start mb-2">
              <div class="flex-1">
                <h3 class="font-semibold text-gray-900">{@portfolio_transaction.asset.name}</h3>
              </div>
              <div class="text-right">
                <span class={[
                  "inline-flex px-2 py-1 text-xs font-medium rounded-full",
                  if(@portfolio_transaction.action == "buy",
                    do: "bg-green-100 text-green-800",
                    else: "bg-red-100 text-red-800"
                  )
                ]}>
                  {String.upcase(@portfolio_transaction.action)}
                </span>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p class="text-gray-500">Quantity</p>
                <p class="font-medium">{Decimal.to_string(@portfolio_transaction.quantity)}</p>
              </div>
              <div>
                <p class="text-gray-500">Price</p>
                <p class="font-medium">
                  {Money.to_string!(@portfolio_transaction.price)}
                </p>
              </div>
              <div>
                <p class="text-gray-500">Commission</p>
                <p class="font-medium">
                  {Money.to_string!(@portfolio_transaction.commission)}
                </p>
              </div>
              <div>
                <p class="text-gray-500">Total Amount</p>
                <p class="font-medium text-lg text-emerald-600">
                  {Money.to_string!(@portfolio_transaction.amount)}
                </p>
              </div>
            </div>

            <p class="text-sm text-gray-500 mt-3">
              {Calendar.strftime(@portfolio_transaction.transaction_date, "%B %d, %Y at %I:%M %p")}
            </p>
          </div>

          <div id={"portfolio-transaction-edit-#{@portfolio_transaction.id}"} class="hidden">
            <div id={"portfolio-transaction-edit-errors-#{@portfolio_transaction.id}"}></div>

            <div class="relative">
              <!-- Loading overlay -->
              <div
                id={"portfolio-transaction-edit-overlay-#{@portfolio_transaction.id}"}
                class="htmx-indicator absolute inset-0 bg-gray-100 bg-opacity-75 flex items-center justify-center rounded-lg z-10"
              >
                <div class="text-center">
                  <svg
                    class="h-8 w-8 animate-spin text-emerald-600 mx-auto mb-2"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  <p class="text-sm text-gray-700">Saving transaction...</p>
                </div>
              </div>

              <form
                id={"portfolio-transaction-edit-form-#{@portfolio_transaction.id}"}
                hx-put={~p"/portfolio_transactions/#{@portfolio_transaction.id}"}
                hx-target={"#portfolio-transaction-#{@portfolio_transaction.id}"}
                hx-swap="outerHTML"
                hx-indicator={"#portfolio-transaction-edit-overlay-#{@portfolio_transaction.id}"}
                hx-on::response-error={"document.getElementById('portfolio-transaction-edit-errors-#{@portfolio_transaction.id}').innerHTML = event.detail.xhr.responseText;"}
                hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
                class="space-y-3"
              >
                <div>
                  <label
                    for={"edit_asset_id_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Asset
                  </label>
                  <select
                    id={"edit_asset_id_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[asset_id]"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  >
                    <%= for asset <- Boonorbust2.Assets.list_assets() do %>
                      <option value={asset.id} selected={@portfolio_transaction.asset_id == asset.id}>
                        {asset.name}
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label
                    for={"edit_action_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Action
                  </label>
                  <select
                    id={"edit_action_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[action]"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  >
                    <option value="buy" selected={@portfolio_transaction.action == "buy"}>Buy</option>
                    <option value="sell" selected={@portfolio_transaction.action == "sell"}>
                      Sell
                    </option>
                  </select>
                </div>

                <div>
                  <label
                    for={"edit_quantity_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Quantity
                  </label>
                  <input
                    type="number"
                    step="any"
                    min="0"
                    id={"edit_quantity_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[quantity]"
                    value={Decimal.to_string(@portfolio_transaction.quantity)}
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_currency_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Currency
                  </label>
                  <select
                    id={"edit_currency_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[currency]"
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  >
                    <%= for currency <- Currency.supported_currencies() do %>
                      <option
                        value={currency}
                        selected={@portfolio_transaction.price.currency == String.to_atom(currency)}
                      >
                        {currency}
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label
                    for={"edit_price_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Price per Share
                  </label>
                  <input
                    type="number"
                    step="any"
                    min="0"
                    id={"edit_price_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[price]"
                    value={Decimal.to_string(@portfolio_transaction.price.amount)}
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_commission_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Commission
                  </label>
                  <input
                    type="number"
                    step="any"
                    min="0"
                    id={"edit_commission_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[commission]"
                    value={Decimal.to_string(@portfolio_transaction.commission.amount)}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label
                    for={"edit_transaction_date_#{@portfolio_transaction.id}"}
                    class="block text-sm font-medium text-gray-700"
                  >
                    Transaction Date
                  </label>
                  <input
                    type="datetime-local"
                    id={"edit_transaction_date_#{@portfolio_transaction.id}"}
                    name="portfolio_transaction[transaction_date]"
                    value={
                      DateTime.to_naive(@portfolio_transaction.transaction_date)
                      |> NaiveDateTime.to_iso8601()
                    }
                    required
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                  />
                </div>

                <div class="flex gap-2">
                  <button
                    type="submit"
                    class="bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-1 px-3 rounded text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
                  >
                    Save
                  </button>
                  <button
                    type="button"
                    onclick={"document.getElementById('portfolio-transaction-view-#{@portfolio_transaction.id}').classList.remove('hidden'); document.getElementById('portfolio-transaction-edit-#{@portfolio_transaction.id}').classList.add('hidden');"}
                    class="bg-gray-600 hover:bg-gray-700 text-white font-medium py-1 px-3 rounded text-sm focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <div class="flex gap-2 ml-4">
          <button
            onclick={"document.getElementById('portfolio-transaction-view-#{@portfolio_transaction.id}').classList.add('hidden'); document.getElementById('portfolio-transaction-edit-#{@portfolio_transaction.id}').classList.remove('hidden');"}
            class="text-emerald-600 hover:text-emerald-800"
            title="Edit transaction"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              >
              </path>
            </svg>
          </button>
          <button
            hx-delete={~p"/portfolio_transactions/#{@portfolio_transaction.id}"}
            hx-target={"#portfolio-transaction-#{@portfolio_transaction.id}"}
            hx-swap="outerHTML"
            hx-confirm="Are you sure you want to delete this transaction?"
            hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
            class="text-red-600 hover:text-red-800"
            title="Delete transaction"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              >
              </path>
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a
              href={~p"/portfolio_transactions"}
              class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block"
            >
              ← Back to Portfolio
            </a>
            <div class="bg-white rounded-lg shadow p-6">
              <div class="flex justify-between items-start mb-4">
                <h1 class="text-2xl font-bold text-gray-900">{@portfolio_transaction.asset.name}</h1>
                <span class={[
                  "inline-flex px-3 py-1 text-sm font-medium rounded-full",
                  if(@portfolio_transaction.action == "buy",
                    do: "bg-green-100 text-green-800",
                    else: "bg-red-100 text-red-800"
                  )
                ]}>
                  {String.upcase(@portfolio_transaction.action)}
                </span>
              </div>

              <div class="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <p class="text-gray-500">Quantity</p>
                  <p class="font-medium">{Decimal.to_string(@portfolio_transaction.quantity)}</p>
                </div>
                <div>
                  <p class="text-gray-500">Price per Share</p>
                  <p class="font-medium">
                    {Money.to_string!(@portfolio_transaction.price)}
                  </p>
                </div>
                <div>
                  <p class="text-gray-500">Commission</p>
                  <p class="font-medium">
                    {Money.to_string!(@portfolio_transaction.commission)}
                  </p>
                </div>
              </div>

              <div class="mb-4">
                <p class="text-gray-500">Total Amount</p>
                <p class="text-3xl font-bold text-emerald-600">
                  {Money.to_string!(@portfolio_transaction.amount)}
                </p>
              </div>

              <p class="text-sm text-gray-500 mb-6">
                {Calendar.strftime(@portfolio_transaction.transaction_date, "%B %d, %Y at %I:%M %p")}
              </p>

              <div class="flex gap-3">
                <a
                  href={~p"/portfolio_transactions/#{@portfolio_transaction}/edit"}
                  class="bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg"
                >
                  Edit Transaction
                </a>
                <button
                  hx-delete={~p"/portfolio_transactions/#{@portfolio_transaction.id}"}
                  hx-confirm="Are you sure you want to delete this transaction?"
                  hx-headers={Jason.encode!(%{"x-csrf-token" => get_csrf_token()})}
                  hx-on--after-request="window.location.href = '/portfolio_transactions'"
                  class="bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-lg"
                >
                  Delete Transaction
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def new(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a
              href={~p"/portfolio_transactions"}
              class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block"
            >
              ← Back to Portfolio
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Add New Transaction</h1>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <.form for={@changeset} action={~p"/portfolio_transactions"} class="space-y-4">
              <div>
                <.label for="portfolio_transaction_asset_id">Asset</.label>
                <.input
                  type="select"
                  field={@changeset[:asset_id]}
                  required
                  options={
                    [{"Select an asset", ""}] ++
                      Enum.map(@assets, &{&1.name, &1.id})
                  }
                />
              </div>

              <div>
                <.label for="portfolio_transaction_action">Action</.label>
                <.input
                  type="select"
                  field={@changeset[:action]}
                  required
                  options={[{"Select action", ""}, {"Buy", "buy"}, {"Sell", "sell"}]}
                />
              </div>

              <div>
                <.label for="portfolio_transaction_quantity">Quantity</.label>
                <.input type="number" step="any" min="0" field={@changeset[:quantity]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_price">Price per Share</.label>
                <.input type="number" step="any" min="0" field={@changeset[:price]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_commission">Commission</.label>
                <.input type="number" step="any" min="0" field={@changeset[:commission]} />
              </div>

              <div>
                <.label for="portfolio_transaction_amount">Total Amount</.label>
                <.input type="number" step="any" min="0" field={@changeset[:amount]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_transaction_date">Transaction Date</.label>
                <.input type="datetime-local" field={@changeset[:transaction_date]} required />
              </div>

              <div class="flex gap-3 pt-4">
                <.button type="submit" class="flex-1 bg-emerald-600 hover:bg-emerald-700">
                  Add Transaction
                </.button>
                <a
                  href={~p"/portfolio_transactions"}
                  class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg text-center"
                >
                  Cancel
                </a>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def edit(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a
              href={~p"/portfolio_transactions/#{@portfolio_transaction}"}
              class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block"
            >
              ← Back to Transaction
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Edit Transaction</h1>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <.form
              for={@changeset}
              action={~p"/portfolio_transactions/#{@portfolio_transaction}"}
              method="put"
              class="space-y-4"
            >
              <div>
                <.label for="portfolio_transaction_asset_id">Asset</.label>
                <.input
                  type="select"
                  field={@changeset[:asset_id]}
                  required
                  options={Enum.map(@assets, &{&1.name, &1.id})}
                />
              </div>

              <div>
                <.label for="portfolio_transaction_action">Action</.label>
                <.input
                  type="select"
                  field={@changeset[:action]}
                  required
                  options={[{"Buy", "buy"}, {"Sell", "sell"}]}
                />
              </div>

              <div>
                <.label for="portfolio_transaction_quantity">Quantity</.label>
                <.input type="number" step="any" min="0" field={@changeset[:quantity]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_price">Price per Share</.label>
                <.input type="number" step="any" min="0" field={@changeset[:price]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_commission">Commission</.label>
                <.input type="number" step="any" min="0" field={@changeset[:commission]} />
              </div>

              <div>
                <.label for="portfolio_transaction_amount">Total Amount</.label>
                <.input type="number" step="any" min="0" field={@changeset[:amount]} required />
              </div>

              <div>
                <.label for="portfolio_transaction_transaction_date">Transaction Date</.label>
                <.input type="datetime-local" field={@changeset[:transaction_date]} required />
              </div>

              <div class="flex gap-3 pt-4">
                <.button type="submit" class="flex-1 bg-emerald-600 hover:bg-emerald-700">
                  Update Transaction
                </.button>
                <a
                  href={~p"/portfolio_transactions/#{@portfolio_transaction}"}
                  class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg text-center"
                >
                  Cancel
                </a>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
