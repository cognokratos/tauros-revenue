defmodule TaurosWeb.InvoiceComponents do
  @moduledoc """
  The invoice vocabulary of the UI: statuses, the lifecycle, the exact
  financial intent of a revision, and its history.

  These components only display what the domain returns. Every rule (who may
  decide, whether a destination is usable, whether a revision is current) is
  enforced by the Ash actions.

  User-facing terms (see docs/UX.md):

    * **Pending approval**: the state; for an approver it **needs review**.
    * **Changes requested**: a draft a human sent back; the agent must revise it.
    * **Withdraw**: the agent or its owner takes back an undecided proposal.
    * **Cancel**: an approver cancels an approved invoice.
  """
  use Phoenix.Component
  use TaurosWeb, :verified_routes

  import TaurosWeb.CoreComponents

  alias Tauros.Revenue.{Currency, FinancialPayload, Network}

  @doc """
  The status a human reads, from the state and, for drafts, whether a human
  sent the current revision back. Needs `current_revision.approval` loaded to
  recognize "Changes requested".
  """
  def status(%{state: :draft, current_revision: %{approval: %{decision: :changes_requested}}}),
    do: {"Changes requested", :warning}

  def status(%{state: :draft}), do: {"Draft", :neutral}
  def status(%{state: :pending_approval}), do: {"Pending approval", :info}
  def status(%{state: :approved}), do: {"Approved", :success}
  def status(%{state: :rejected}), do: {"Rejected", :error}
  def status(%{state: :cancelled}), do: {"Cancelled", :neutral}

  @doc "An invoice status chip: text and colour, never colour alone."
  attr :invoice, :map, required: true
  attr :id, :string, default: nil

  def invoice_status(assigns) do
    {label, tone} = status(assigns.invoice)
    assigns = assign(assigns, label: label, tone: tone)

    ~H"""
    <span
      id={@id}
      class={[
        "badge badge-sm whitespace-nowrap",
        @tone == :info && "badge-info",
        @tone == :success && "badge-success",
        @tone == :warning && "badge-warning",
        @tone == :error && "badge-error badge-outline",
        @tone == :neutral && "badge-ghost"
      ]}
    >
      {@label}
    </span>
    """
  end

  @doc """
  The lifecycle as a short strip: Draft → Pending approval → Approved, with
  the end state actually reached (Rejected or Cancelled) where it happened.
  """
  attr :invoice, :map, required: true

  def lifecycle(assigns) do
    assigns = assign(assigns, :steps, lifecycle_steps(assigns.invoice))

    ~H"""
    <ol
      id="lifecycle"
      class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm"
      aria-label="Lifecycle"
    >
      <%= for {{label, status}, index} <- Enum.with_index(@steps) do %>
        <li :if={index > 0} aria-hidden="true" class="opacity-40">→</li>
        <li
          data-step={label}
          aria-current={status == :current && "step"}
          class={[
            "rounded-full px-2.5 py-0.5",
            status == :current && "bg-base-content text-base-100 font-semibold",
            status == :done && "opacity-80",
            status == :todo && "opacity-40"
          ]}
        >
          {label}
        </li>
      <% end %>
    </ol>
    """
  end

  defp lifecycle_steps(%{state: state} = invoice) do
    case {state, status(invoice)} do
      {:draft, {"Changes requested", _}} ->
        [
          {"Pending approval", :done},
          {"Changes requested", :current},
          {"Revised and resubmitted", :todo},
          {"Approved", :todo}
        ]

      {:rejected, _} ->
        [{"Draft", :done}, {"Pending approval", :done}, {"Rejected", :current}]

      {:cancelled, _} ->
        [{"Draft", :done}, {"Cancelled", :current}]

      {_, {current, _}} ->
        main_line(current)
    end
  end

  defp main_line(current) do
    main = ["Draft", "Pending approval", "Approved"]
    index = Enum.find_index(main, &(&1 == current))

    for {label, i} <- Enum.with_index(main) do
      cond do
        i < index -> {label, :done}
        i == index -> {label, :current}
        true -> {label, :todo}
      end
    end
  end

  @doc "An amount in its currency, never rounded: at least two decimals, every significant digit."
  def money(amount, currency) do
    places = max(scale(amount), min(Currency.decimals(currency), 2))
    "#{amount |> Decimal.round(places) |> Decimal.to_string(:normal)} #{currency}"
  end

  defp scale(amount) do
    case Decimal.normalize(amount) do
      %Decimal{exp: exp} when exp < 0 -> -exp
      _ -> 0
    end
  end

  @doc "A long address shortened for lists, e.g. `0x1234…7890`."
  def short_address(address) when byte_size(address) > 14,
    do: String.slice(address, 0, 6) <> "…" <> String.slice(address, -4, 4)

  def short_address(address), do: address

  @doc "A short, readable time: \"3 min ago\", \"5 h ago\", or a date."
  def ago(%DateTime{} = at, now \\ DateTime.utc_now()) do
    seconds = DateTime.diff(now, at)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} h ago"
      seconds < 7 * 86_400 -> "#{div(seconds, 86_400)} d ago"
      true -> Calendar.strftime(at, "%Y-%m-%d")
    end
  end

  @doc """
  Who did something, in words: "You", the agent's name, or "a human".
  `agent_names` maps agent ids to names (the viewer's own agents).
  """
  def actor_label(%{actor_kind: :agent, actor_id: id}, agent_names, _viewer),
    do: Map.get(agent_names, id, "an agent")

  def actor_label(%{actor_kind: :human, actor_id: id}, _agent_names, %{id: id}), do: "You"
  def actor_label(%{actor_kind: :human}, _agent_names, _viewer), do: "a human"

  @doc """
  What an invoice command did, as a phrase around `object` ("this invoice",
  "the invoice for Acme Inc"): `did(:submit_for_approval, "this invoice")` is
  "submitted this invoice for approval".
  """
  def did(:create_draft, object), do: "proposed #{object}"
  def did(:revise, object), do: "revised #{object}"
  def did(:submit_for_approval, object), do: "submitted #{object} for approval"
  def did(:withdraw, object), do: "withdrew #{object}"
  def did(:approve, object), do: "approved #{object}"
  def did(:reject, object), do: "rejected #{object}"
  def did(:request_changes, object), do: "requested changes to #{object}"
  def did(:cancel, object), do: "cancelled #{object}"

  @doc "The viewer's agents, as `%{id => name}`, for naming actors."
  def agent_names(user),
    do: [actor: user] |> Tauros.Accounts.list_agents!() |> Map.new(&{&1.id, &1.name})

  @doc "A compact card for the review queue."
  attr :invoice, :map, required: true
  attr :selected?, :boolean, default: false
  attr :patch, :string, required: true

  def proposal_card(assigns) do
    ~H"""
    <.link
      patch={@patch}
      aria-current={@selected? && "true"}
      class={[
        "block rounded-box border p-4 transition",
        @selected? && "border-primary bg-primary/5",
        !@selected? && "border-base-300 bg-base-100 hover:border-primary/50"
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <p class="font-semibold">{@invoice.current_revision.customer.name}</p>
        <p class="whitespace-nowrap font-mono text-sm">
          {money(@invoice.current_revision.total, @invoice.current_revision.currency)}
        </p>
      </div>
      <p class="mt-1 text-xs opacity-70">
        from {@invoice.agent.name} · due {@invoice.current_revision.due_date}
      </p>
      <p class="mt-2 line-clamp-1 text-sm opacity-80">{@invoice.current_revision.reasoning}</p>
    </.link>
    """
  end

  @doc """
  The exact financial intent of the current revision: the summary sentence,
  the agent's reasoning and the lines. `invoice` must have `agent` and
  `current_revision` with `customer` and `payment_destination` loaded.
  """
  attr :invoice, :map, required: true
  attr :summary_label, :string, default: "What this revision states"

  def financial_intent(assigns) do
    assigns = assign(assigns, :revision, assigns.invoice.current_revision)

    ~H"""
    <div id="financial-intent" class="space-y-6">
      <div class="rounded-box border border-base-300 bg-base-100 p-4">
        <p class="text-xs font-semibold uppercase tracking-wide opacity-70">{@summary_label}</p>
        <p id="intent-summary" class="mt-2 text-lg leading-relaxed">
          <span class="font-semibold">{@revision.customer.name}</span>
          owes <span class="font-mono font-semibold">{money(@revision.total, @revision.currency)}</span>,
          payable on
          <span class="font-semibold">{Network.label(@revision.payment_destination.network)}</span>
          to <span class="break-all font-mono">{@revision.payment_destination.address}</span>,
          due <span class="font-semibold">{@revision.due_date}</span>.
        </p>
      </div>

      <section aria-labelledby="reasoning-heading">
        <h3 id="reasoning-heading" class="text-sm font-semibold">Why this invoice exists</h3>
        <p class="text-xs opacity-70">Reasoning from {@invoice.agent.name}, an AI agent</p>
        <blockquote
          id="agent-reasoning"
          class="mt-2 whitespace-pre-line border-l-4 border-base-300 pl-4 text-sm"
        >
          {@revision.reasoning}
        </blockquote>
      </section>

      <section aria-labelledby="lines-heading">
        <h3 id="lines-heading" class="text-sm font-semibold">Lines</h3>
        <div class="overflow-x-auto">
          <table id="invoice-lines" class="table table-sm">
            <thead>
              <tr>
                <th>Description</th>
                <th class="text-right">Qty</th>
                <th class="hidden text-right sm:table-cell">Unit</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={line <- @revision.lines}>
                <td>{line.description}</td>
                <td class="text-right font-mono">{Decimal.to_string(line.quantity, :normal)}</td>
                <td class="hidden text-right font-mono sm:table-cell">
                  {money(line.unit_amount, @revision.currency)}
                </td>
                <td class="whitespace-nowrap text-right font-mono">
                  {money(FinancialPayload.line_amount(line), @revision.currency)}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th class="text-right" colspan="2">Total</th>
                <th class="hidden sm:table-cell"></th>
                <th id="invoice-total" class="whitespace-nowrap text-right font-mono">
                  {money(@revision.total, @revision.currency)}
                </th>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>
    </div>
    """
  end

  @doc """
  The record details of the current revision: customer, destination,
  revision and its fingerprint (the payload hash), with the exact bytes
  folded away. Needs `revisions` loaded.
  """
  attr :invoice, :map, required: true

  def revision_details(assigns) do
    assigns = assign(assigns, :revision, assigns.invoice.current_revision)

    ~H"""
    <section id="revision-details" aria-labelledby="details-heading" class="space-y-2">
      <h3 id="details-heading" class="text-sm font-semibold">Details</h3>
      <.list>
        <:item title="Customer">
          {@revision.customer.name} <span class="opacity-70">({@revision.customer.email})</span>
        </:item>
        <:item title="Paid to">
          <span class="mr-2">{@revision.payment_destination.label}</span>
          <.state_badge id="destination-state" state={@revision.payment_destination.state} />
          <span class="block text-xs opacity-70">
            {@revision.currency} on {Network.label(@revision.payment_destination.network)} ({Network.rail(
              @revision.payment_destination.network
            )} rail)
          </span>
        </:item>
        <:item title="Revision">
          <span id="revision-number">{@revision.number} of {length(@invoice.revisions)}</span>
          <span class="block text-xs opacity-70">
            Any change to the money creates a new revision; a revision never changes once created.
          </span>
        </:item>
        <:item title="Fingerprint">
          <code id="payload-hash" class="select-all break-all font-mono text-xs">
            {@revision.payload_hash}
          </code>
          <span class="block text-xs opacity-70">
            SHA-256 of the exact financial payload. An approval names this fingerprint.
          </span>
        </:item>
        <:item title="Reference">
          <span class="font-mono text-xs">{@invoice.idempotency_key}</span>
          <span class="block text-xs opacity-70">The agent's idempotency key.</span>
        </:item>
      </.list>

      <details class="text-sm">
        <summary class="cursor-pointer opacity-70">
          Canonical payload (the exact bytes hashed)
        </summary>
        <pre class="mt-2 overflow-x-auto rounded-box bg-base-200 p-3 text-xs"><code id="canonical-payload">{@revision.canonical_payload}</code></pre>
      </details>
    </section>
    """
  end

  @doc "The audit envelope as a timeline, oldest first, with named actors."
  attr :events, :list, required: true
  attr :agent_names, :map, default: %{}
  attr :viewer, :map, required: true

  def history(assigns) do
    ~H"""
    <section aria-labelledby="history-heading">
      <h3 id="history-heading" class="text-sm font-semibold">History</h3>
      <ol id="invoice-history" class="mt-2 space-y-3 border-l border-base-300 pl-4">
        <li :for={event <- @events} id={"event-#{event.id}"} class="text-sm">
          <p>
            <span class="font-semibold">{actor_label(event, @agent_names, @viewer)}</span>
            {did(event.action, "this invoice")}
            <span class="opacity-60">
              · {Calendar.strftime(event.occurred_at, "%Y-%m-%d %H:%M UTC")} · via {event.interface}
            </span>
          </p>
          <p :if={event.note} class="whitespace-pre-line opacity-80">{event.note}</p>
        </li>
      </ol>
    </section>
    """
  end
end
