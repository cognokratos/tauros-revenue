defmodule Tauros.Accounts do
  use Ash.Domain,
    otp_app: :tauros

  resources do
    resource Tauros.Accounts.Token
    resource Tauros.Accounts.User
  end
end
