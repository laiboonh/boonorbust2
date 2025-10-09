defmodule Boonorbust2Web.PortfolioHTML do
  use Boonorbust2Web, :html

  embed_templates "portfolio_html/*"

  def tags_card_display(assigns) do
    ~H"""
    <%= if @tags && !Enum.empty?(@tags) do %>
      <div class="mt-4 flex flex-wrap gap-2">
        <%= for tag <- @tags do %>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            {tag.name}
          </span>
        <% end %>
      </div>
    <% end %>
    """
  end
end
