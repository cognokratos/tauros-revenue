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

  acme =
    Revenue.create_customer!(
      %{name: "Acme Inc", email: "billing@acme.example", agent_id: agent.id},
      actor: human
    )

  globex =
    Revenue.create_customer!(
      %{name: "Globex GmbH", email: "ap@globex.example", agent_id: agent.id},
      actor: human
    )

  # The agent registers where it gets paid. The same currency (USDC) on two
  # networks is two destinations.
  eur =
    Revenue.create_payment_destination!(
      %{
        label: "Operating account",
        currency: :EUR,
        network: :iban,
        address: "DE89370400440532013000"
      },
      actor: agent
    )

  usdc_arbitrum =
    Revenue.create_payment_destination!(
      %{
        label: "Treasury (Arbitrum)",
        currency: :USDC,
        network: :arbitrum,
        address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      },
      actor: agent
    )

  Revenue.create_payment_destination!(
    %{
      label: "Treasury (Ethereum)",
      currency: :USDC,
      network: :ethereum,
      address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
    },
    actor: agent
  )

  # The agent proposes two invoices and submits them for approval, exactly as
  # it would through POST /api/v1/invoices and PATCH /api/v1/invoices/:id/submit.
  due = Date.add(Date.utc_today(), 30)

  for {key, customer, destination, lines, reasoning} <- [
        {"seed-acme-2026-10", acme, usdc_arbitrum,
         [
           %{description: "Platform retainer, October", quantity: "1", unit_amount: "1000"},
           %{description: "Additional support hours", quantity: "4", unit_amount: "50"}
         ],
         "Acme's statement of work (signed 2026-09-12) sets a 1,000 USDC monthly retainer, " <>
           "paid on Arbitrum. Their ticket log shows 4 hours of extra support at 50 USDC/hour."},
        {"seed-globex-2026-10", globex, eur,
         [%{description: "Integration workshop (2 days)", quantity: "2", unit_amount: "1450.00"}],
         "Globex accepted quote Q-2026-031 for a two-day workshop at EUR 1,450 per day. " <>
           "The workshop took place on 1-2 October."}
      ] do
    %{
      idempotency_key: key,
      customer_id: customer.id,
      payment_destination_id: destination.id,
      currency: destination.currency,
      due_date: due,
      lines: lines,
      reasoning: reasoning
    }
    |> Revenue.create_invoice_draft!(actor: agent)
    |> Revenue.submit_invoice!(actor: agent)
  end

  IO.puts("""
  Demo approver: #{email} / #{password}  (two proposals wait at /approvals)
  Agent API key (shown once): #{agent.__metadata__.plaintext_api_key}
  """)
end
