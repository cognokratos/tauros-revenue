defmodule Tauros.Accounts.User do
  @moduledoc """
  A human. Humans sign in to the UI (password or magic link) or obtain a
  bearer token for the API, own agents, and hold financial authority.

  Registration is closed. The first approver is created (or, after an
  upgrade, promoted) with `bootstrap_approver`; everyone after that is
  invited by an approver. A human's `role` (`Tauros.Accounts.Role`) is fixed
  when they are invited.
  """
  use Ash.Resource,
    otp_app: :tauros,
    domain: Tauros.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshAuthentication]

  alias Tauros.Accounts.Checks.{AgentActor, HumanActor, HumanApprover, NoApproverYet}

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:reset_password_with_token]
        sender Tauros.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Tauros.Accounts.Token
      signing_secret Tauros.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        # Closed: a magic link signs in an existing (invited) human only.
        registration_enabled? false
        require_interaction? true

        sender Tauros.Accounts.User.Senders.SendMagicLinkEmail
      end

      remember_me :remember_me

      password :password do
        identity_field :email
        hash_provider AshAuthentication.Argon2Provider
        # Closed: strangers cannot register and give themselves authority.
        registration_enabled? false

        resettable do
          sender Tauros.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end
    end
  end

  json_api do
    type "user"
  end

  postgres do
    table "users"
    repo Tauros.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    read :sign_in_with_magic_link do
      description "Sign in an existing human with a magic link. It never registers anyone."
      get? true

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      prepare AshAuthentication.Strategy.MagicLink.SignInPreparation

      prepare {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenPreparation,
               strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    create :invite do
      description """
      An approver invites a human by email, as an operator or an approver. The
      invitee signs in with a magic link, or sets a password through "Forgot
      your password?".
      """

      accept [:email, :role]
    end

    create :bootstrap_approver do
      description """
      Make `email` the first approver, creating that human if needed. Allowed
      only while no approver exists: on a fresh installation, or once after
      upgrading from before roles existed. Run it from a console or the seeds.
      The human then signs in with a magic link or sets a password through
      "Forgot your password?".
      """

      accept [:email]
      change set_attribute(:role, :approver)
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:role]
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy [action(:read), HumanActor] do
      description "A human may read their own record (e.g. as the approver of a decision)"
      authorize_if expr(id == ^actor(:id))
    end

    policy [action(:change_password), HumanActor] do
      description "Users may change only their own password"
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:sign_in_with_password) do
      description "Anyone may attempt to sign in through the JSON API"
      authorize_if always()
    end

    policy action(:invite) do
      description "Only an approver may bring another human into Tauros"
      authorize_if HumanApprover
    end

    policy action(:bootstrap_approver) do
      description "The first approver can be designated only while there is none, never by an agent"
      forbid_if AgentActor
      authorize_if NoApproverYet
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :role, Tauros.Accounts.Role do
      description "operator or approver. Set on invitation; no action changes it."
      allow_nil? false
      default :operator
      public? true
    end
  end

  relationships do
    has_many :agents, Tauros.Accounts.Agent
  end

  identities do
    identity :unique_email, [:email]
  end
end
