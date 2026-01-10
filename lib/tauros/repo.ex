defmodule Tauros.Repo do
  use Ecto.Repo,
    otp_app: :tauros,
    adapter: Ecto.Adapters.Postgres
end
