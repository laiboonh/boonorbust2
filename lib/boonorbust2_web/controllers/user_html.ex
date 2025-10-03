defmodule Boonorbust2Web.UserHTML do
  use Boonorbust2Web, :html

  alias Boonorbust2.Currency

  def edit_modal(assigns) do
    ~H"""
    <div
      id="user-edit-modal"
      class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    >
      <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
        <div class="mt-3">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900">Edit Profile</h3>
            <button
              onclick="document.getElementById('user-edit-modal').remove()"
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

          <form
            hx-put={~p"/user"}
            hx-target="#user-name-display"
            hx-swap="outerHTML"
            hx-on--after-request="document.getElementById('user-edit-modal').remove()"
            class="space-y-4"
          >
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />

            <div>
              <label for="user_name" class="block text-sm font-medium text-gray-700">
                Name
              </label>
              <input
                type="text"
                id="user_name"
                name="user[name]"
                value={@user.name}
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
              />
              <%= if @changeset.errors[:name] do %>
                <p class="mt-1 text-sm text-red-600">
                  {translate_errors(@changeset.errors, :name) |> Enum.join(", ")}
                </p>
              <% end %>
            </div>

            <div>
              <label for="user_currency" class="block text-sm font-medium text-gray-700">
                Preferred Currency
              </label>
              <select
                id="user_currency"
                name="user[currency]"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
              >
                <%= for {label, value} <- Currency.currency_options() do %>
                  <option value={value} selected={@user.currency == value}>{label}</option>
                <% end %>
              </select>
              <%= if @changeset.errors[:currency] do %>
                <p class="mt-1 text-sm text-red-600">
                  {translate_errors(@changeset.errors, :currency) |> Enum.join(", ")}
                </p>
              <% end %>
            </div>

            <div class="flex gap-3 pt-4">
              <button
                type="submit"
                class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
              >
                Save Changes
              </button>
              <button
                type="button"
                onclick="document.getElementById('user-edit-modal').remove()"
                class="flex-1 bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def header_user_info(assigns) do
    ~H"""
    <a
      id="user-name-display"
      hx-get={~p"/user/edit"}
      hx-target="body"
      hx-swap="beforeend"
      class="text-sm text-emerald-600 hover:text-emerald-700 underline hover:no-underline transition-all duration-200"
      title="Click to edit your profile"
    >
      Hello, {@user.name}!
    </a>
    """
  end

  def edit(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <div class="mb-6">
            <a href={~p"/dashboard"} class="text-emerald-600 hover:text-emerald-800 mb-4 inline-block">
              ← Back
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Edit Profile</h1>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <.form for={@changeset} action={~p"/user"} method="put" class="space-y-4">
              <div>
                <.label for="user_name">Name</.label>
                <.input type="text" field={@changeset[:name]} required />
              </div>

              <div>
                <.label for="user_currency">Preferred Currency</.label>
                <.input
                  type="select"
                  field={@changeset[:currency]}
                  required
                  options={Currency.currency_options()}
                />
              </div>

              <div class="flex gap-3 pt-4">
                <.button type="submit" class="flex-1 bg-emerald-600 hover:bg-emerald-700">
                  Save Changes
                </.button>
                <a
                  href={~p"/dashboard"}
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
