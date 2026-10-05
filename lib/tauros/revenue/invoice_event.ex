defmodule Tauros.Revenue.InvoiceEvent do
  @moduledoc """
  A lightweight audit envelope: one row per invoice command that changed
  something, written in the same transaction as the change.

  It answers who (actor id and kind), what (action and state change), how
  (interface), which exact payload (revision and payload hash), why (the
  agent's reasoning or the human's reason) and, for creates, which
  idempotency key.

  This is deliberately smaller than the full history planned for Epic 5
  (AshPaperTrail versions and database-enforced append-only tables). Events
  have no update or destroy action, and no actor may create one: only
  `Invoice.Changes.RecordEvent` writes them, from inside an authorized action.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}

  json_api do
    type "invoice_event"
  end

  postgres do
    table "invoice_events"
    repo Tauros.Repo

    references do
      reference :invoice, on_delete: :restrict, index?: true
      reference :revision, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    create :record do
      description "Written only by Invoice.Changes.RecordEvent; no actor is authorized to call it."

      accept [
        :invoice_id,
        :action,
        :from_state,
        :to_state,
        :actor_id,
        :actor_kind,
        :interface,
        :revision_id,
        :payload_hash,
        :idempotency_key,
        :note
      ]
    end
  end

  policies do
    policy [action_type(:read), HumanActor] do
      description "Humans read the history of their agents' invoices"
      authorize_if relates_to_actor_via([:invoice, :agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents read the history of their own invoices"
      authorize_if relates_to_actor_via([:invoice, :agent])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :action, :atom do
      description "The Invoice action, e.g. :create_draft or :approve."
      allow_nil? false
      public? true
    end

    attribute :from_state, :atom, public?: true
    attribute :to_state, :atom, allow_nil?: false, public?: true

    attribute :actor_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :actor_kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:human, :agent]
    end

    attribute :interface, Tauros.Revenue.Interface do
      allow_nil? false
      public? true
    end

    attribute :payload_hash, :string, public?: true
    attribute :idempotency_key, :string, public?: true

    attribute :note, :string do
      description "The agent's reasoning, or the human's reason."
      public? true
    end

    create_timestamp :occurred_at, public?: true
  end

  relationships do
    belongs_to :invoice, Tauros.Revenue.Invoice do
      allow_nil? false
      public? true
    end

    belongs_to :revision, Tauros.Revenue.InvoiceRevision do
      description "The revision the command concerned (created, submitted or decided)."
      public? true
    end
  end
end
