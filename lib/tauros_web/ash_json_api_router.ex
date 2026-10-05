defmodule TaurosWeb.AshJsonApiRouter do
  @moduledoc """
  JSON:API router generated from the routes declared on the Ash domains.
  """
  use AshJsonApi.Router,
    domains: [Tauros.Accounts, Tauros.Revenue],
    open_api: "/open_api"
end
