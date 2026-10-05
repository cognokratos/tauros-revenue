defmodule Tauros.Mailer do
  @moduledoc "Delivers authentication emails (magic links, confirmations, password resets)."
  use Swoosh.Mailer, otp_app: :tauros

  @doc "The `from` address, configured with `config :tauros, :mail_sender, {name, address}`."
  def sender, do: Application.get_env(:tauros, :mail_sender, {"Tauros", "noreply@tauros.local"})
end
