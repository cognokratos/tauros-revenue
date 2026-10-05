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
  human =
    Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: password,
      password_confirmation: password
    })
    |> Ash.create!(authorize?: false)

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
  Signed-in human: #{email} / #{password}
  Agent API key (shown once): #{agent.__metadata__.plaintext_api_key}
  """)
end
