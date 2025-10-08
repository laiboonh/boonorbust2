defmodule Boonorbust2Web.TagHTML do
  use Boonorbust2Web, :html

  def tags_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@tags) do %>
      <p class="text-sm text-gray-500">No tags yet. Add one below.</p>
    <% else %>
      <div class="flex flex-wrap gap-2">
        <%= for tag <- @tags do %>
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
            {tag.name}
            <button
              hx-delete={~p"/tags/#{@asset_id}/#{tag.id}"}
              hx-target={"#tags-list-#{@asset_id}"}
              hx-swap="innerHTML"
              class="ml-2 text-blue-600 hover:text-blue-800"
              title="Remove tag"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                >
                </path>
              </svg>
            </button>
          </span>
        <% end %>
      </div>
    <% end %>
    <!-- Out-of-band swap to update tags in the position card -->
    <div id={"tags-card-#{@asset_id}"} hx-swap-oob="innerHTML">
      <%= if !Enum.empty?(@tags) do %>
        <div class="mt-4 flex flex-wrap gap-2">
          <%= for tag <- @tags do %>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              {tag.name}
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <div class="text-red-600 text-sm">{@message}</div>
    """
  end
end
