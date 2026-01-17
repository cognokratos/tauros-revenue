defmodule TaurosWeb.Router do
  use TaurosWeb, :router

  import TaurosWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TaurosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_agent do
    plug :accepts, ["json"]
    plug TaurosWeb.AgentAuth
  end

  pipeline :api_admin do
    plug :accepts, ["json"]
    plug :require_admin_api_token
  end

  scope "/", TaurosWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", TaurosWeb.Api.Agent do
    pipe_through :api_agent

    get "/v1/test", TestController, :show
  end

  scope "/api/admin", TaurosWeb.Api.Admin do
    pipe_through :api

    post "/v1/login", LoginController, :create
  end

  scope "/api/admin", TaurosWeb.Api.Admin do
    pipe_through :api_admin

    get "/v1/test", TestController, :show
    post "/v1/agents", AgentController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tauros, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TaurosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TaurosWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TaurosWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/agents", AgentLive.Index, :index
      live "/agents/new", AgentLive.Form, :new
      live "/agents/:id", AgentLive.Show, :show
      live "/agents/:id/edit", AgentLive.Form, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TaurosWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TaurosWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
