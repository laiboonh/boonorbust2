defmodule Boonorbust2Web.Router do
  use Boonorbust2Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Boonorbust2Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Boonorbust2Web.Auth, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/auth", Boonorbust2Web do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  scope "/", Boonorbust2Web do
    pipe_through :browser

    get "/", PageController, :home
    get "/messages", MessageController, :index
    post "/messages", MessageController, :create
    delete "/messages/:id", MessageController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", Boonorbust2Web do
  #   pipe_through :api
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:boonorbust2, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
