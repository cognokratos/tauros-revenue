defmodule Tauros.Revenue.Approval do
  @moduledoc """
  A human decision about one exact invoice revision: approved, rejected, or
  changes requested.

  An approval names the revision and its payload hash, the human approver,
  when, and why. It is append-only: there is no update or destroy action, and
  a revision can receive at most one decision (a unique index on
  `revision_id`). It can only be written by an `Invoice` decision action
  (`approve`, `reject`, `request_changes`), and only for a human approver who
  owns the proposing agent. No agent can create one, whatever it calls.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor, HumanApprover}

  json_api do
    type "approval"
  end

  postgres do
    table "approvals"
    repo Tauros.Repo

    references do
      reference :invoice, on_delete: :restrict, index?: true
      reference :revision, on_delete: :restrict
      reference :approver, on_delete: :restrict, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      description "Written by Invoice.approve, reject and request_changes."
      accept [:revision_id, :payload_hash, :decision, :reason]
      change relate_actor(:approver)
    end
  end

  policies do
    policy action_type(:create) do
      description "Only an Invoice decision, made by a human approver who owns the proposing agent"
      forbid_unless accessing_from(Tauros.Revenue.Invoice, :approvals)
      forbid_unless HumanApprover
      authorize_if relates_to_actor_via([:invoice, :agent, :user])
    end

    policy [action_type(:read), HumanActor] do
      description "Humans read decisions on their agents' invoices"
      authorize_if relates_to_actor_via([:invoice, :agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents read decisions on their own invoices, to learn what to change"
      authorize_if relates_to_actor_via([:invoice, :agent])
    end
  end

  validations do
    validate Tauros.Revenue.Approval.Validations.NamesItsRevision,
      before_action?: true,
      only_when_valid?: true
  end

  attributes do
    uuid_primary_key :id

    attribute :decision, Tauros.Revenue.Decision do
      allow_nil? false
      public? true
    end

    attribute :payload_hash, :string do
      description "The SHA-256 of the exact payload the approver decided on."
      allow_nil? false
      public? true
      constraints match: ~r/^[0-9a-f]{64}$/
    end

    attribute :reason, :string do
      description "Why. Required to reject or request changes; optional to approve."
      public? true
      constraints trim?: true, max_length: 2000
    end

    create_timestamp :decided_at, public?: true
  end

  relationships do
    belongs_to :invoice, Tauros.Revenue.Invoice do
      allow_nil? false
      public? true
    end

    belongs_to :revision, Tauros.Revenue.InvoiceRevision do
      allow_nil? false
      public? true
    end

    belongs_to :approver, Tauros.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :one_decision_per_revision, [:revision_id] do
      description "A revision is decided once. Deciding again needs a new revision."
    end
  end
end
