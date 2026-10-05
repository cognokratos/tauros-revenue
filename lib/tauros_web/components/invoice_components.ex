defmodule TaurosWeb.InvoiceComponents do
  @moduledoc """
  Shows an invoice revision as the exact financial intent a human is asked to
  authorize. Used by the approval inbox and the invoice pages.

  These components only display what the domain returns. Every rule
  (who may decide, whether a destination is usable, whether the revision is
  current) is enforced by the Ash actions.
  """
  use Phoenix.Component
  use TaurosWeb, :verified_routes

  import TaurosWeb.CoreComponents

  alias Tauros.Revenue.{Currency, Network}

  @doc """
  An amount in its currency, never rounded: shown with at least two decimals
  (or the currency's own, if fewer) and every significant digit it has.
  """
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

  @doc "A compact card for a list of proposals."
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
        !@selected? && "border-base-300 hover:border-primary/50"
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <p class="font-semibold">{@invoice.current_revision.customer.name}</p>
        <p class="whitespace-nowrap font-mono text-sm">
          {money(@invoice.current_revision.total, @invoice.current_revision.currency)}
        </p>
      </div>
      <p class="mt-1 text-xs opacity-70">
        {Network.label(@invoice.current_revision.payment_destination.network)} ·
        <span class="font-mono">
          {short_address(@invoice.current_revision.payment_destination.address)}
        </span>
        · due {@invoice.current_revision.due_date}
      </p>
      <p class="mt-2 line-clamp-1 text-sm opacity-80">{@invoice.current_revision.reasoning}</p>
    </.link>
    """
  end

  @doc """
  The exact financial intent of the current revision. `invoice` must have
  `agent`, `revisions` and `current_revision` with `customer` and
  `payment_destination` loaded.
  """
  attr :invoice, :map, required: true

  def financial_intent(assigns) do
    assigns = assign(assigns, :revision, assigns.invoice.current_revision)

    ~H"""
    <div id="financial-intent" class="space-y-6">
      <div class="rounded-box border border-base-300 bg-base-200/50 p-4">
        <p class="text-xs font-semibold uppercase tracking-wide opacity-70">
          What approving authorizes
        </p>
        <p id="intent-summary" class="mt-2 text-lg leading-relaxed">
          <span class="font-semibold">{@revision.customer.name}</span>
          owes <span class="font-semibold font-mono">{money(@revision.total, @revision.currency)}</span>,
          payable on
          <span class="font-semibold">{Network.label(@revision.payment_destination.network)}</span>
          to <span class="break-all font-mono">{@revision.payment_destination.address}</span>,
          due <span class="font-semibold">{@revision.due_date}</span>.
        </p>
      </div>

      <section aria-labelledby="reasoning-heading">
        <h3 id="reasoning-heading" class="text-sm font-semibold">Why this invoice exists</h3>
        <p class="text-xs opacity-70">Reasoning from agent {@invoice.agent.name}</p>
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
                <th class="text-right">Quantity</th>
                <th class="text-right">Unit</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={line <- @revision.lines}>
                <td>{line.description}</td>
                <td class="text-right font-mono">{Decimal.to_string(line.quantity, :normal)}</td>
                <td class="text-right font-mono">{money(line.unit_amount, @revision.currency)}</td>
                <td class="text-right font-mono">
                  {money(Decimal.mult(line.quantity, line.unit_amount), @revision.currency)}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th colspan="3" class="text-right">Total</th>
                <th id="invoice-total" class="text-right font-mono">
                  {money(@revision.total, @revision.currency)}
                </th>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <.list>
        <:item title="Customer">
          {@revision.customer.name} <span class="opacity-70">({@revision.customer.email})</span>
        </:item>
        <:item title="Destination">
          <span class="mr-2">{@revision.payment_destination.label}</span>
          <.state_badge id="destination-state" state={@revision.payment_destination.state} />
          <span class="block text-xs opacity-70">
            {@revision.currency} on {Network.label(@revision.payment_destination.network)} ({Network.rail(
              @revision.payment_destination.network
            )} rail)
          </span>
        </:item>
        <:item title="Revision">
          <span id="revision-number">
            {@revision.number} of {length(@invoice.revisions)}
          </span>
        </:item>
        <:item title="Payload SHA-256">
          <code id="payload-hash" class="select-all break-all font-mono text-xs">
            {@revision.payload_hash}
          </code>
        </:item>
      </.list>

      <details class="text-sm">
        <summary class="cursor-pointer opacity-70">
          Canonical payload (the exact bytes hashed)
        </summary>
        <pre class="mt-2 overflow-x-auto rounded-box bg-base-200 p-3 text-xs"><code id="canonical-payload">{@revision.canonical_payload}</code></pre>
      </details>
    </div>
    """
  end

  @doc "The audit envelope as a timeline. `events` must be loaded, oldest first."
  attr :events, :list, required: true

  def history(assigns) do
    ~H"""
    <section aria-labelledby="history-heading">
      <h3 id="history-heading" class="text-sm font-semibold">History</h3>
      <ol id="invoice-history" class="mt-2 space-y-3 border-l border-base-300 pl-4">
        <li :for={event <- @events} id={"event-#{event.id}"} class="text-sm">
          <p>
            <span class="font-semibold">{humanize(event.action)}</span>
            <span class="opacity-70">
              by {if event.actor_kind == :agent, do: "agent", else: "human"} via {event.interface}, {Calendar.strftime(
                event.occurred_at,
                "%Y-%m-%d %H:%M UTC"
              )}
            </span>
          </p>
          <p :if={event.payload_hash} class="font-mono text-xs opacity-60">
            {String.slice(event.payload_hash, 0, 12)}…
          </p>
          <p :if={event.note} class="whitespace-pre-line opacity-80">{event.note}</p>
        </li>
      </ol>
    </section>
    """
  end

  defp humanize(action), do: action |> to_string() |> String.replace("_", " ")
end
