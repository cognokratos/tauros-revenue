defmodule Tauros.Revenue.WalletAccount do
  @moduledoc """
  A public receiving destination (on-chain address or IBAN) an agent registers
  for collecting payments.

  Tauros stores only public identifiers. Keys, seeds and signing belong to a
  custody system such as Arktos, never to Tauros. Wallet accounts are
  append-only: there is no update or destroy action.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}
  alias Tauros.Revenue.Currency

  json_api do
    type "wallet_account"
  end

  postgres do
    table "wallet_accounts"
    repo Tauros.Repo

    references do
      reference :agent, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:wallet_name, :public_address, :currency]
      change relate_actor(:agent)
    end
  end

  policies do
    policy action_type(:create) do
      description "Agents register their own wallet accounts"
      authorize_if AgentActor
    end

    policy [action_type(:read), HumanActor] do
      description "Humans see the wallet accounts of the agents they own"
      authorize_if relates_to_actor_via([:agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents see only their own wallet accounts"
      authorize_if relates_to_actor_via(:agent)
    end
  end

  validations do
    validate match(:public_address, ~r/^bc1p[a-z0-9]{38,60}$/),
      where: attribute_in(:currency, Currency.bitcoin()),
      message: "must be a valid Taproot Bitcoin address",
      only_when_valid?: true

    validate match(:public_address, ~r/^0x[a-fA-F0-9]{40}$/),
      where: attribute_in(:currency, Currency.ethereum()),
      message: "must be a valid Ethereum address",
      only_when_valid?: true

    validate match(:public_address, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/),
      where: attribute_in(:currency, Currency.fiat()),
      message: "must be a valid IBAN",
      only_when_valid?: true
  end

  attributes do
    uuid_primary_key :id

    attribute :wallet_name, :string do
      allow_nil? false
      public? true
      constraints trim?: true, max_length: 160
    end

    attribute :public_address, :string do
      allow_nil? false
      public? true
      constraints trim?: true
    end

    attribute :currency, Currency do
      allow_nil? false
      public? true
    end

    timestamps public?: true
  end

  relationships do
    belongs_to :agent, Tauros.Accounts.Agent do
      allow_nil? false
      public? true
    end
  end
end
