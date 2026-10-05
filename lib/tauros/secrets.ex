defmodule Tauros.Secrets do
  @moduledoc """
  Supplies the token signing secret to AshAuthentication.
  """
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Tauros.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:tauros, :token_signing_secret)
  end
end
