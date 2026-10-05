defmodule TaurosWeb.ApiAuth do
  @moduledoc """
  Authentication glue for the JSON:API.

  Every client sends one header, `Authorization: Bearer <credential>`:

    * humans send the token returned by `POST /api/v1/users/sign-in`
      (resolved by AshAuthentication's `load_from_bearer`)
    * agents send their API key (resolved by `AshAuthentication.Strategy.ApiKey.Plug`)

  Whichever resolves becomes the Ash actor. This module only rejects requests
  that carry no valid credential; everything else is decided by Ash policies.
  """
  import Plug.Conn

  @public_paths [
    ["api", "v1", "users", "sign-in"],
    ["api", "v1", "open_api"]
  ]

  @doc "`on_error` for the API key plug: a human token is not an API key, so carry on."
  def ignore_invalid_api_key(conn, _error), do: conn

  @doc "Halts with 401 unless a human or agent was authenticated."
  def require_actor(conn, _opts) do
    if Ash.PlugHelpers.get_actor(conn) || conn.path_info in @public_paths do
      conn
    else
      body = %{
        errors: [
          %{
            status: "401",
            code: "unauthorized",
            title: "Unauthorized",
            detail: "A valid bearer token or agent API key is required"
          }
        ]
      }

      conn
      |> put_resp_content_type("application/vnd.api+json")
      |> send_resp(401, Jason.encode!(body))
      |> halt()
    end
  end
end
