defmodule Tauros.Revenue.Invoice do
  @moduledoc """
  The first financial aggregate: an invoice an agent proposes and a human
  decides on.

  The invoice holds identity and lifecycle. Its financial content lives in
  immutable `InvoiceRevision`s; the latest one is `current_revision`. Every
  change of content appends a revision with a new payload hash. Nothing that
  was proposed, submitted or approved is ever edited in place.

  `state` is an AshStateMachine. No action accepts it; every move is a named
  action listed in `transitions`.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource, AshStateMachine],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor, HumanApprover}
  alias Tauros.Revenue.Changes.Transition
  alias Tauros.Revenue.Invoice.Changes.{Decide, ProposeRevision}

  json_api do
    type "invoice"
    includes [:current_revision, :revisions, :approvals, :events]
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :revise, from: [:draft, :pending_approval], to: :draft
      transition :submit_for_approval, from: :draft, to: :pending_approval
      transition :withdraw, from: [:draft, :pending_approval], to: :cancelled
      transition :approve, from: :pending_approval, to: :approved
      transition :reject, from: :pending_approval, to: :rejected
      transition :request_changes, from: :pending_approval, to: :draft
      transition :cancel, from: :approved, to: :cancelled
    end
  end

  postgres do
    table "invoices"
    repo Tauros.Repo

    references do
      reference :agent, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    read :awaiting_approval do
      description "Invoices waiting for a human decision, oldest first."
      filter expr(state == :pending_approval)
      prepare build(sort: [updated_at: :asc])
    end

    create :create_draft do
      description """
      Propose an invoice as the calling agent. Retry-safe: the same
      `idempotency_key` with the same financial payload returns the original
      invoice (`idempotent_replay` is true); with a different payload it is
      refused with 409 `idempotency_conflict`.
      """

      accept [:idempotency_key]

      argument :customer_id, :uuid do
        description "One of the agent's customers."
        allow_nil? false
      end

      argument :payment_destination_id, :uuid do
        description "One of the agent's active payment destinations, receiving `currency`."
        allow_nil? false
      end

      argument :currency, Tauros.Revenue.Currency, allow_nil?: false
      argument :due_date, :date, allow_nil?: false

      argument :lines, {:array, Tauros.Revenue.InvoiceLine} do
        allow_nil? false
        constraints min_length: 1, max_length: 100
      end

      argument :reasoning, :string do
        description "Why the agent proposes this invoice. Shown to the approver."
        allow_nil? false
        constraints trim?: true, min_length: 1, max_length: 4000
      end

      change relate_actor(:agent)
      change ProposeRevision

      metadata :idempotent_replay, :boolean do
        description "True when this call replayed an earlier one with the same key and payload."
        allow_nil? false
      end
    end

    update :revise do
      description """
      Propose new content for a draft or pending invoice. Omitted fields keep
      their current values. A new immutable revision with a new payload hash
      is appended and the invoice returns to draft. Revising to exactly the
      current payload changes nothing.
      """

      accept []
      require_atomic? false

      argument :customer_id, :uuid
      argument :payment_destination_id, :uuid
      argument :currency, Tauros.Revenue.Currency
      argument :due_date, :date

      argument :lines, {:array, Tauros.Revenue.InvoiceLine} do
        constraints min_length: 1, max_length: 100
      end

      argument :reasoning, :string do
        description "Why the agent revises the invoice. Shown to the approver."
        allow_nil? false
        constraints trim?: true, min_length: 1, max_length: 4000
      end

      change {Transition, to: :draft}
      change ProposeRevision
    end

    update :submit_for_approval do
      description """
      Ask a human approver to decide on the current revision. Retry-safe:
      submitting an invoice that is already pending changes nothing.
      """

      accept []
      require_atomic? false
      change {Transition, to: :pending_approval, idempotent?: true}
      validate Tauros.Revenue.Invoice.Validations.Submittable, before_action?: true
    end

    update :withdraw do
      description """
      Withdraw a proposal nobody has approved: the invoice is kept, cancelled.
      Retry-safe.
      """

      accept []
      require_atomic? false
      change {Transition, to: :cancelled, idempotent?: true}
    end

    update :approve do
      description """
      HUMAN AUTHORITY. Authorize exactly one revision: name it with
      `revision_id` and its `payload_hash`. Fails if it is no longer the
      current revision, if the hash differs, or if its destination was
      retired. Retry-safe for the same approver.
      """

      accept []
      require_atomic? false
      argument :revision_id, :uuid, allow_nil?: false

      argument :payload_hash, :string do
        allow_nil? false
        constraints match: ~r/^[0-9a-f]{64}$/
      end

      argument :reason, :string, constraints: [trim?: true, max_length: 2000]
      change {Decide, decision: :approved, to: :approved}
    end

    update :reject do
      description "HUMAN AUTHORITY. Refuse one exact revision for good, with a reason."
      accept []
      require_atomic? false
      argument :revision_id, :uuid, allow_nil?: false

      argument :payload_hash, :string do
        allow_nil? false
        constraints match: ~r/^[0-9a-f]{64}$/
      end

      argument :reason, :string do
        allow_nil? false
        constraints trim?: true, min_length: 1, max_length: 2000
      end

      change {Decide, decision: :rejected, to: :rejected}
    end

    update :request_changes do
      description """
      HUMAN AUTHORITY. Send one exact revision back to the agent, with a
      reason. The invoice returns to draft; the agent must revise before
      submitting again.
      """

      accept []
      require_atomic? false
      argument :revision_id, :uuid, allow_nil?: false

      argument :payload_hash, :string do
        allow_nil? false
        constraints match: ~r/^[0-9a-f]{64}$/
      end

      argument :reason, :string do
        allow_nil? false
        constraints trim?: true, min_length: 1, max_length: 2000
      end

      change {Decide, decision: :changes_requested, to: :draft}
    end

    update :cancel do
      description """
      HUMAN AUTHORITY. Cancel an approved invoice before it is issued, with a
      reason. Retry-safe.
      """

      accept []
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
        constraints trim?: true, min_length: 1, max_length: 2000
      end

      change {Transition, to: :cancelled, idempotent?: true}
    end
  end

  policies do
    policy [action_type(:read), HumanActor] do
      description "Humans see the invoices of the agents they own"
      authorize_if relates_to_actor_via([:agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents see only their own invoices"
      authorize_if relates_to_actor_via(:agent)
    end

    policy action(:create_draft) do
      description "Only agents propose invoices, always as themselves"
      authorize_if AgentActor
    end

    policy action([:revise, :submit_for_approval]) do
      description "An agent revises and submits only its own proposals"
      forbid_unless AgentActor
      authorize_if relates_to_actor_via(:agent)
    end

    policy [action(:withdraw), AgentActor] do
      description "An agent may withdraw its own undecided proposal"
      authorize_if relates_to_actor_via(:agent)
    end

    policy [action(:withdraw), HumanActor] do
      description "The owning human, approver or not, may withdraw an undecided proposal"
      authorize_if relates_to_actor_via([:agent, :user])
    end

    # AI capability is not financial authority. This is the policy that stops
    # an agent (or an operator) from approving, whatever interface it uses.
    policy action([:approve, :reject, :request_changes, :cancel]) do
      description "Only a human approver who owns the proposing agent decides"
      forbid_unless HumanApprover
      authorize_if relates_to_actor_via([:agent, :user])
    end
  end

  changes do
    change Tauros.Revenue.Invoice.Changes.RecordEvent, on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id

    attribute :idempotency_key, :string do
      description "Chosen by the agent; unique per agent. Retrying with it is safe."
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1, max_length: 200
    end

    timestamps public?: true
  end

  relationships do
    belongs_to :agent, Tauros.Accounts.Agent do
      allow_nil? false
      public? true
    end

    has_many :revisions, Tauros.Revenue.InvoiceRevision do
      public? true
      sort number: :asc
    end

    has_many :approvals, Tauros.Revenue.Approval do
      public? true
      sort decided_at: :asc
    end

    has_many :events, Tauros.Revenue.InvoiceEvent do
      description "The audit envelope: one event per command that changed something."
      public? true
      sort occurred_at: :asc
    end

    has_one :current_revision, Tauros.Revenue.InvoiceRevision do
      description "The latest revision: what would be submitted, reviewed and approved."
      public? true
      from_many? true
      sort number: :desc
    end
  end

  identities do
    identity :idempotency_key_per_agent, [:agent_id, :idempotency_key]
  end
end
