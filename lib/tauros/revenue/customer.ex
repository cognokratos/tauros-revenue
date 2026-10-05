defmodule Tauros.Revenue.Customer do
  @moduledoc """
  A party Tauros bills. Every customer is owned by exactly one agent, and
  through it by that agent's human. Ownership is fixed at creation: no
  action accepts `agent_id` after the customer exists.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Revenue,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor}

  json_api do
    type "customer"
  end

  postgres do
    table "customers"
    repo Tauros.Repo

    references do
      reference :agent, on_delete: :restrict, index?: true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :email, :agent_id]
    end

    update :update do
      primary? true
      accept [:name, :email]
    end
  end

  policies do
    policy [action_type(:read), AgentActor] do
      description "Agents read their own customers, to address proposals to them"
      authorize_if relates_to_actor_via(:agent)
    end

    policy action_type([:create, :update, :destroy]) do
      description "Customers are managed by the human who owns the customer's agent"
      forbid_unless HumanActor
      authorize_if relates_to_actor_via([:agent, :user])
    end

    policy [action_type(:read), HumanActor] do
      description "Humans read the customers of the agents they own"
      authorize_if relates_to_actor_via([:agent, :user])
    end
  end

  validations do
    validate match(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/) do
      where changing(:email)
      message "must have the @ sign and no spaces"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints trim?: true, max_length: 160
    end

    attribute :email, :string do
      allow_nil? false
      public? true
      constraints trim?: true, max_length: 160
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
