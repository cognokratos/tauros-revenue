defmodule Tauros.Fixtures do
  @moduledoc """
  Test data built through the same Ash actions the application uses,
  so fixtures obey the same policies and validations.
  """
  alias Tauros.{Accounts, Revenue}

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def valid_password, do: "correct horse battery staple"

  def user(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{email: unique_email(), password: valid_password()})

    Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: attrs.email,
      password: attrs.password,
      password_confirmation: attrs.password
    })
    |> Ash.create!(authorize?: false)
  end

  @doc "Returns the user with a session token in its metadata, as after signing in."
  def with_token(user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    Ash.Resource.put_metadata(user, :token, token)
  end

  @doc "Creates an agent owned by `user`. The plaintext key is in `agent.__metadata__.plaintext_api_key`."
  def agent(user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Agent #{System.unique_integer([:positive])}"})
    Accounts.create_agent!(attrs.name, actor: user)
  end

  def customer(agent, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Customer #{System.unique_integer([:positive])}",
        email: unique_email(),
        agent_id: agent.id
      })

    owner = Ash.get!(Accounts.User, agent.user_id, authorize?: false)
    Revenue.create_customer!(attrs, actor: owner)
  end

  def payment_destination(agent, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        label: "Destination #{System.unique_integer([:positive])}",
        currency: :USDC,
        network: :ethereum,
        address: "0x1234567890123456789012345678901234567890"
      })

    Revenue.create_payment_destination!(attrs, actor: agent)
  end
end
