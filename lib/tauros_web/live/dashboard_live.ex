defmodule TaurosWeb.DashboardLive do
  @moduledoc """
  The overview: what needs the human's attention, where invoices are in their
  lifecycle, and what agents and humans did recently. Everything is read
  through the same policies as the rest of the UI.
  """
  use TaurosWeb, :live_view

  import TaurosWeb.InvoiceComponents

  alias Tauros.Revenue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        Overview
        <:subtitle>Agents propose, the domain constrains, a human approver decides.</:subtitle>
      </.header>

      <section
        id="attention"
        aria-labelledby="attention-heading"
        class="rounded-box border border-base-300 bg-base-100 p-5"
      >
        <h2 id="attention-heading" class="text-xs font-semibold uppercase tracking-wide opacity-60">
          Needs your attention
        </h2>

        <%= if @pending == [] do %>
          <p id="attention-clear" class="mt-2 text-lg">Nothing needs your review.</p>
          <p :if={@counts.total == 0} class="mt-1 text-sm opacity-70">
            No invoices yet. Agents create invoice proposals through the REST API or MCP; they
            appear here when they are submitted for approval.
          </p>
        <% else %>
          <div class="mt-2 flex flex-col gap-3 sm:flex-row sm:items-baseline sm:justify-between">
            <p id="attention-count" class="text-lg">
              <span class="text-2xl font-semibold">{@pending_count}</span>
              {if @pending_count == 1, do: "proposal is", else: "proposals are"} waiting for {if @current_user.role ==
                                                                                                   :approver,
                                                                                                 do:
                                                                                                   "your decision",
                                                                                                 else:
                                                                                                   "an approver"}.
            </p>
            <.link
              :if={@current_user.role == :approver}
              id="review-oldest"
              navigate={~p"/invoices/#{hd(@pending)}/review"}
              class="btn btn-primary btn-sm"
            >
              Review the oldest
            </.link>
          </div>
          <ul id="pending-preview" class="mt-4 divide-y divide-base-300">
            <li :for={invoice <- @pending} id={"pending-#{invoice.id}"}>
              <.link
                navigate={~p"/invoices/#{invoice}/review"}
                class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-2 hover:bg-base-200/50"
              >
                <span>
                  <span class="font-medium">{invoice.current_revision.customer.name}</span>
                  <span class="text-sm opacity-60">from {invoice.agent.name} · {ago(
                    invoice.updated_at
                  )}</span>
                </span>
                <span class="font-mono text-sm">
                  {money(invoice.current_revision.total, invoice.current_revision.currency)}
                </span>
              </.link>
            </li>
          </ul>
          <.link
            :if={@pending_count > length(@pending)}
            navigate={~p"/invoices/review"}
            class="link mt-2 inline-block text-sm"
          >
            All {@pending_count} waiting
          </.link>
        <% end %>
      </section>

      <section aria-labelledby="workflow-heading">
        <h2
          id="workflow-heading"
          class="mb-2 text-xs font-semibold uppercase tracking-wide opacity-60"
        >
          Invoices by state
        </h2>
        <div id="workflow" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <.stat
            id="stat-review"
            label="Pending approval"
            value={@counts.review}
            path={~p"/invoices?status=review"}
          />
          <.stat
            id="stat-draft"
            label="Drafts"
            value={@counts.draft}
            path={~p"/invoices?status=draft"}
            note={@counts.changes_requested > 0 && "#{@counts.changes_requested} sent back"}
          />
          <.stat
            id="stat-approved"
            label="Approved"
            value={@counts.approved}
            path={~p"/invoices?status=approved"}
          />
          <.stat
            id="stat-closed"
            label="Rejected / cancelled"
            value={@counts.closed}
            path={~p"/invoices?status=closed"}
          />
        </div>
      </section>

      <section aria-labelledby="activity-heading">
        <h2
          id="activity-heading"
          class="mb-2 text-xs font-semibold uppercase tracking-wide opacity-60"
        >
          Recent activity
        </h2>
        <p :if={@activity == []} id="activity-empty" class="text-sm opacity-70">
          Nothing yet. Invoice proposals, revisions and decisions show up here.
        </p>
        <ol
          :if={@activity != []}
          id="activity"
          class="divide-y divide-base-300 rounded-box border border-base-300 bg-base-100"
        >
          <li :for={event <- @activity} id={"activity-#{event.id}"}>
            <.link
              navigate={~p"/invoices/#{event.invoice_id}"}
              class="flex flex-wrap items-baseline justify-between gap-x-4 px-4 py-2 text-sm hover:bg-base-200/50"
            >
              <span>
                <span class="font-medium">{actor_label(event, @agent_names, @current_user)}</span>
                {did(event.action, "the invoice for #{event.invoice.current_revision.customer.name}")}
                <span class="opacity-60">
                  · {money(
                    event.invoice.current_revision.total,
                    event.invoice.current_revision.currency
                  )}
                </span>
              </span>
              <span class="whitespace-nowrap text-xs opacity-60">
                {ago(event.occurred_at)} · via {event.interface}
              </span>
            </.link>
          </li>
        </ol>
      </section>

      <section aria-labelledby="setup-heading" class="text-sm">
        <h2 id="setup-heading" class="sr-only">Setup</h2>
        <p id="setup" class="opacity-70">
          <.link navigate={~p"/agents"} class="link link-hover">{count(@setup.agents, "agent")}</.link>
          ·
          <.link navigate={~p"/customers"} class="link link-hover">{count(
            @setup.customers,
            "customer"
          )}</.link>
          ·
          <.link navigate={~p"/destinations"} class="link link-hover">
            {count(@setup.destinations, "active payment destination")}
          </.link>
        </p>
      </section>
    </Layouts.app>
    """
  end

  defp count(1, noun), do: "1 #{noun}"
  defp count(n, noun), do: "#{n} #{noun}s"

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :path, :string, required: true
  attr :note, :any, default: nil

  defp stat(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@path}
      class="rounded-box border border-base-300 bg-base-100 p-4 transition hover:border-base-content/30"
    >
      <span class="block text-sm opacity-70">{@label}</span>
      <span class="mt-1 block text-2xl font-semibold">{@value}</span>
      <span :if={@note} class="block text-xs opacity-70">{@note}</span>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    pending =
      Revenue.list_invoices_awaiting_approval!(
        actor: actor,
        load: [:agent, current_revision: :customer]
      )

    invoices = Revenue.list_invoices!(actor: actor, load: [current_revision: :approval])

    counts = %{
      total: length(invoices),
      review: Enum.count(invoices, &(&1.state == :pending_approval)),
      draft: Enum.count(invoices, &(&1.state == :draft)),
      changes_requested: Enum.count(invoices, &(status(&1) == {"Changes requested", :warning})),
      approved: Enum.count(invoices, &(&1.state == :approved)),
      closed: Enum.count(invoices, &(&1.state in [:rejected, :cancelled]))
    }

    activity =
      Revenue.InvoiceEvent
      |> Ash.Query.sort(occurred_at: :desc)
      |> Ash.Query.limit(8)
      |> Ash.Query.load(invoice: [current_revision: :customer])
      |> Ash.read!(actor: actor)

    setup = %{
      agents: Ash.count!(Tauros.Accounts.Agent, actor: actor),
      customers: Ash.count!(Revenue.Customer, actor: actor),
      destinations:
        Revenue.PaymentDestination
        |> Ash.Query.for_read(:active, %{}, actor: actor)
        |> Ash.count!()
    }

    {:ok,
     assign(socket,
       page_title: "Overview",
       pending: Enum.take(pending, 3),
       pending_count: length(pending),
       counts: counts,
       activity: activity,
       agent_names: agent_names(actor),
       setup: setup
     )}
  end
end
