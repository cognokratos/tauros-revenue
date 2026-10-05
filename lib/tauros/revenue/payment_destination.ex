defmodule Tauros.Revenue.PaymentDestination do
  @moduledoc """
  Where an agent is paid: a currency, the network it arrives on, and a public
  receiving address on that network (an on-chain address or an IBAN).

  Tauros stores only public identifiers. Keys, seeds and signing belong to a
  custody system such as Arktos, never to Tauros. A destination's details
  cannot change: there is no update action, so a corrected destination is a
  new record.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}

  json_api do
    type "payment_destination"
  end

  postgres do
    table "payment_destinations"
    repo Tauros.Repo

    references do
      reference :agent, on_delete: :restrict, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      description "Register a receiving destination for the calling agent."
      accept [:label, :currency, :network, :address]
      change relate_actor(:agent)
    end
  end

  policies do
    policy action_type(:create) do
      description "Agents register their own payment destinations"
      authorize_if AgentActor
    end

    policy [action_type(:read), HumanActor] do
      description "Humans see the payment destinations of the agents they own"
      authorize_if relates_to_actor_via([:agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents see only their own payment destinations"
      authorize_if relates_to_actor_via(:agent)
    end
  end

  validations do
    validate Tauros.Revenue.PaymentDestination.Validations.Receivable, only_when_valid?: true
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      description "A name for humans, e.g. \"Treasury (Arbitrum)\"."
      allow_nil? false
      public? true
      constraints trim?: true, max_length: 160
    end

    attribute :currency, Tauros.Revenue.Currency do
      allow_nil? false
      public? true
    end

    attribute :network, Tauros.Revenue.Network do
      description "The blockchain network or bank scheme the payment arrives on."
      allow_nil? false
      public? true
    end

    attribute :address, :string do
      description "The public receiving address on `network`: an on-chain address or an IBAN."
      allow_nil? false
      public? true
      constraints trim?: true, max_length: 128
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
