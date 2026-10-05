defmodule TaurosWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Tauros.Accounts, Tauros.Revenue],
    open_api: "/open_api"
end
