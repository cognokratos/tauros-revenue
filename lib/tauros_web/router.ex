defmodule TaurosWeb.Router do
  use TaurosWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers
  import TaurosWeb.ApiAuth, only: [require_actor: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TaurosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Tauros.Accounts.Agent,
      required?: false,
      on_error: &TaurosWeb.ApiAuth.ignore_invalid_api_key/2

    plug :require_actor
  end

  scope "/", TaurosWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: {TaurosWeb.LiveUserAuth, :live_user_required} do
      live "/", DashboardLive, :index

      live "/agents", AgentLive.Index, :index
      live "/agents/new", AgentLive.Form, :new
      live "/agents/:id/edit", AgentLive.Form, :edit
      live "/agents/:id", AgentLive.Show, :show

      live "/customers", CustomerLive.Index, :index
      live "/customers/new", CustomerLive.Form, :new
      live "/customers/:id/edit", CustomerLive.Form, :edit
      live "/customers/:id", CustomerLive.Show, :show

      live "/wallet-accounts", WalletAccountLive.Index, :index
      live "/wallet-accounts/:id", WalletAccountLive.Show, :show
    end
  end

  scope "/api" do
    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/v1/open_api",
      default_model_expand_depth: 4
  end

  scope "/api/v1" do
    pipe_through [:api]

    forward "/", TaurosWeb.AshJsonApiRouter
  end

  scope "/", TaurosWeb do
    pipe_through :browser

    auth_routes AuthController, Tauros.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      overrides: [TaurosWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{TaurosWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    TaurosWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [TaurosWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the confirmation strategy
    confirm_route Tauros.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [TaurosWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Tauros.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [TaurosWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", TaurosWeb do
  #   pipe_through :api
  # end

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
end
