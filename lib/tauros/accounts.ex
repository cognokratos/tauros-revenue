defmodule Tauros.Accounts do
  @moduledoc """
  Who may act in Tauros: humans (`User`) and the agents they register (`Agent`),
  plus their credentials (`Token`, `ApiKey`).
  """
  use Ash.Domain, otp_app: :tauros, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/users", Tauros.Accounts.User do
        post :sign_in_with_password do
          route "/sign-in"
          metadata fn _subject, user, _request -> %{token: user.__metadata__.token} end
        end
      end

      base_route "/agents", Tauros.Accounts.Agent do
        index :read
        get :read

        post :create do
          metadata fn _subject, agent, _request ->
            %{api_key: agent.__metadata__.plaintext_api_key}
          end
        end

        patch :update

        patch :rotate_api_key do
          route "/:id/rotate-api-key"

          metadata fn _subject, agent, _request ->
            %{api_key: agent.__metadata__.plaintext_api_key}
          end
        end

        delete :destroy
      end
    end
  end

  resources do
    resource Tauros.Accounts.Token
    resource Tauros.Accounts.User

    resource Tauros.Accounts.Agent do
      define :list_agents, action: :read, default_options: [query: [sort: [inserted_at: :desc]]]
      define :get_agent, action: :read, get_by: :id
      define :create_agent, action: :create, args: [:name]
      define :update_agent, action: :update
      define :rotate_agent_api_key, action: :rotate_api_key
      define :destroy_agent, action: :destroy
    end

    resource Tauros.Accounts.ApiKey
  end
end
