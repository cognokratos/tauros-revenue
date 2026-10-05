defmodule Tauros.Revenue.PaymentDestination do
  @moduledoc """
  Where an agent is paid: a currency, the network it arrives on, and a public
  receiving address on that network (an on-chain address or an IBAN).

  Tauros stores only public identifiers. Keys, seeds and signing belong to a
  custody system such as Arktos, never to Tauros.

  A destination's details cannot change: no action accepts `label`,
  `currency`, `network` or `address` after creation. What can change is
  whether it may still be used. Its `state` is a state machine:

  ```text
  active ──deactivate──▶ deactivated
     └────supersede───▶ superseded     (a replacement destination names it)
  ```

  Only `active` destinations can be used by new invoice revisions or approved.
  Retired destinations stay on record, because past invoices refer to them.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource, AshStateMachine],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}
  alias Tauros.Revenue.Changes.Transition

  json_api do
    type "payment_destination"
  end

  state_machine do
    initial_states [:active]
    default_initial_state :active

    transitions do
      transition :deactivate, from: :active, to: :deactivated
      transition :supersede, from: :active, to: :superseded
    end
  end

  postgres do
    table "payment_destinations"
    repo Tauros.Repo

    references do
      reference :agent, on_delete: :restrict, index?: true
      reference :supersedes, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      description """
      Register a receiving destination for the calling agent. To correct a
      destination, register its replacement with `supersedes_id`: the old one
      becomes `superseded` in the same transaction.
      """

      accept [:label, :currency, :network, :address, :supersedes_id]
      change relate_actor(:agent)
      change Tauros.Revenue.PaymentDestination.Changes.SupersedePrevious
    end

    update :deactivate do
      description "Stop using this destination for new invoices. Its record is kept."
      accept []
      require_atomic? false
      change {Transition, to: :deactivated}
    end

    update :supersede do
      description "Run by `create` when a replacement names this destination."
      accept []
      require_atomic? false
      change {Transition, to: :superseded}
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

    policy [action(:deactivate), HumanActor] do
      description "The owning human may retire a destination"
      authorize_if relates_to_actor_via([:agent, :user])
    end

    policy [action(:deactivate), AgentActor] do
      description "An agent may retire its own destination"
      authorize_if relates_to_actor_via(:agent)
    end

    # `supersede` has no policy, so no actor can call it directly. It only runs
    # inside `create`, which has already authorized the agent.
  end

  validations do
    validate Tauros.Revenue.PaymentDestination.Validations.Receivable, only_when_valid?: true

    validate Tauros.Revenue.PaymentDestination.Validations.SupersedesOwnDestination,
      where: present(:supersedes_id)
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

    belongs_to :supersedes, __MODULE__ do
      description "The destination this one replaced, if any."
      public? true
    end

    has_one :superseded_by, __MODULE__ do
      description "The destination that replaced this one, if any."
      destination_attribute :supersedes_id
      public? true
    end
  end

  identities do
    identity :one_replacement_each, [:supersedes_id] do
      description "A destination is superseded at most once."
      nils_distinct? true
    end
  end
end
