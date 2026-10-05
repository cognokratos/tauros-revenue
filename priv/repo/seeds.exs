# Demo data for local development: `mix run priv/repo/seeds.exs`
# (also run by `mix setup`). Everything goes through the same Ash actions
# and policies as the application. Safe to re-run.

alias Tauros.{Accounts, Revenue}

email = "demo@tauros.local"
password = "tauros-demo-password"

if Ash.read_one!(Ash.Query.for_read(Accounts.User, :get_by_email, %{email: email}),
     authorize?: false
   ) do
  IO.puts("Seed data already present for #{email}")
else
  # Registration is closed. The first approver is designated through the
  # same action an operator would run from a console on a fresh install.
  human = Accounts.bootstrap_approver!(email)

  # Give the demo approver a known password through the real reset flow.
  strategy = AshAuthentication.Info.strategy!(Accounts.User, :password)
  {:ok, reset_token} = AshAuthentication.Strategy.Password.reset_token_for(strategy, human)

  human =
    human
    |> Ash.Changeset.for_update(:reset_password_with_token, %{
      reset_token: reset_token,
      password: password,
      password_confirmation: password
    })
    |> Ash.update!(authorize?: false)

  agent = Accounts.create_agent!("Billing agent", actor: human)

  Revenue.create_customer!(
    %{name: "Acme Inc", email: "billing@acme.example", agent_id: agent.id},
    actor: human
  )

  Revenue.create_payment_destination!(
    %{
      label: "Operating account",
      currency: :EUR,
      network: :iban,
      address: "DE89370400440532013000"
    },
    actor: agent
  )

  IO.puts("""
  Demo approver: #{email} / #{password}
  Agent API key (shown once): #{agent.__metadata__.plaintext_api_key}
  """)
end
