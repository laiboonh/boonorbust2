defmodule Boonorbust2Web.CoreComponents do
  @moduledoc """
  Provides core UI components: form error alerts, the mobile tab bar/dock
  navigation, and heroicons.
  """
  use Phoenix.Component
  use Gettext, backend: Boonorbust2Web.Gettext

  @doc """
  Renders form validation errors for a changeset.
  """
  attr :changeset, Ecto.Changeset, required: true

  def form_errors(assigns) do
    ~H"""
    <div role="alert" class="alert alert-error alert-soft mb-4 items-start">
      <ul class="list-disc list-inside space-y-1 text-sm">
        <%= for {field, messages} <- @changeset.errors do %>
          <%= for message <- List.wrap(messages) do %>
            <li class="capitalize">
              {Phoenix.Naming.humanize(field)} {translate_error(message)}
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end

  @doc """
  Renders a simple error message.
  """
  attr :message, :string, required: true

  def error_message(assigns) do
    ~H"""
    <div role="alert" class="alert alert-error alert-soft mb-4">
      <svg class="w-5 h-5 shrink-0" fill="currentColor" viewBox="0 0 20 20">
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
          clip-rule="evenodd"
        />
      </svg>
      <span class="text-sm">{@message}</span>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(Boonorbust2Web.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(Boonorbust2Web.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a mobile tab bar for navigation.

  ## Examples

      <.tab_bar current_tab="messages">
        <:tab navigate={~p"/messages"} name="messages" icon="hero-chat-bubble-left">
          Messages
        </:tab>
        <:tab navigate={~p"/assets"} name="assets" icon="hero-chart-bar">
          Assets
        </:tab>
      </.tab_bar>

  """
  attr :current_tab, :string, required: true

  slot :tab, required: true do
    attr :navigate, :string, required: true
    attr :name, :string, required: true
    attr :icon, :string, required: true
  end

  def tab_bar(assigns) do
    ~H"""
    <div class="dock dock-sm z-50">
      <%= for tab <- @tab do %>
        <.link
          navigate={tab.navigate}
          class={
            if @current_tab == tab.name,
              do: "dock-active text-primary",
              else: "text-base-content/60"
          }
        >
          <.icon name={tab.icon} class="size-4" />
          <span class="dock-label">{render_slot(tab)}</span>
        </.link>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a tab content wrapper that adds bottom padding to account for the fixed tab bar.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def tab_content(assigns) do
    ~H"""
    <div class={["pb-20", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
