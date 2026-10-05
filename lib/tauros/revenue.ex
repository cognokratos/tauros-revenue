defmodule Tauros.Revenue do
  @moduledoc """
  The financial core: who Tauros bills (`Customer`) and where payments are
  received (`WalletAccount`). Invoices, approvals and settlement will live here.
  """
  use Ash.Domain, otp_app: :tauros, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/customers", Tauros.Revenue.Customer do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
      end

      base_route "/wallet-accounts", Tauros.Revenue.WalletAccount do
        index :read
        get :read
        post :create
      end
    end
  end

  resources do
    resource Tauros.Revenue.Customer do
      define :list_customers,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :get_customer, action: :read, get_by: :id
      define :create_customer, action: :create
      define :update_customer, action: :update
      define :destroy_customer, action: :destroy
    end

    resource Tauros.Revenue.WalletAccount do
      define :list_wallet_accounts,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_wallet_account, action: :create
    end
  end
end
