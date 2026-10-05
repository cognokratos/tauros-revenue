defmodule Tauros.Revenue.InvoiceRevision do
  @moduledoc """
  One immutable statement of an invoice's financial intent: who is billed,
  what, in which currency, payable where and when, and why the agent proposes
  it.

  Revisions are append-only. There is no update or destroy action, and a
  revision can only be created by an `Invoice` action (`create_draft`,
  `revise`). When a revision is created its `FinancialPayload` is sealed: the
  canonical JSON is stored in `canonical_payload` and its SHA-256 in
  `payload_hash`. A human approval names one revision and its hash, so what
  was approved can never change afterwards. Changing anything means a new
  revision with a new hash.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}

  json_api do
    type "invoice_revision"
  end

  postgres do
    table "invoice_revisions"
    repo Tauros.Repo

    references do
      reference :invoice, on_delete: :restrict
      reference :customer, on_delete: :restrict, index?: true
      reference :payment_destination, on_delete: :restrict, index?: true
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      description "Internal: written by Invoice.create_draft and Invoice.revise."
      accept [:customer_id, :payment_destination_id, :currency, :due_date, :lines, :reasoning]
      change Tauros.Revenue.InvoiceRevision.Changes.Seal
    end
  end

  policies do
    policy action_type(:create) do
      description "Revisions are written only through an Invoice action, by the proposing agent"
      forbid_unless accessing_from(Tauros.Revenue.Invoice, :revisions)
      authorize_if AgentActor
    end

    policy [action_type(:read), HumanActor] do
      description "Humans read the revisions of their agents' invoices"
      authorize_if relates_to_actor_via([:invoice, :agent, :user])
    end

    policy [action_type(:read), AgentActor] do
      description "Agents read the revisions of their own invoices"
      authorize_if relates_to_actor_via([:invoice, :agent])
    end
  end

  validations do
    validate Tauros.Revenue.InvoiceRevision.Validations.UsableReferences,
      before_action?: true,
      only_when_valid?: true

    validate Tauros.Revenue.InvoiceRevision.Validations.AmountsFitCurrency,
      only_when_valid?: true

    validate compare(:due_date, greater_than_or_equal_to: &Date.utc_today/0),
      message: "must not be in the past"
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :integer do
      description "1 for the first revision of an invoice, then 2, 3, …"
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :currency, Tauros.Revenue.Currency do
      allow_nil? false
      public? true
    end

    attribute :due_date, :date do
      allow_nil? false
      public? true
    end

    attribute :lines, {:array, Tauros.Revenue.InvoiceLine} do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :total, :decimal do
      description "Sum of quantity × unit_amount, exactly. Computed, never accepted."
      allow_nil? false
      public? true
    end

    attribute :reasoning, :string do
      description "Why the agent proposes this. Shown to the approver; not part of the payload hash."
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1, max_length: 4000
    end

    attribute :canonical_payload, :string do
      description "The exact bytes that were hashed (see Tauros.Revenue.FinancialPayload)."
      allow_nil? false
      public? true
    end

    attribute :payload_hash, :string do
      description "SHA-256 of canonical_payload, lowercase hex. What an approval names."
      allow_nil? false
      public? true
      constraints match: ~r/^[0-9a-f]{64}$/
    end

    create_timestamp :inserted_at, public?: true
  end

  relationships do
    belongs_to :invoice, Tauros.Revenue.Invoice do
      allow_nil? false
      public? true
    end

    belongs_to :customer, Tauros.Revenue.Customer do
      allow_nil? false
      public? true
    end

    belongs_to :payment_destination, Tauros.Revenue.PaymentDestination do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :number_per_invoice, [:invoice_id, :number]
  end
end
