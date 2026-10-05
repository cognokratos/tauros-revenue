defmodule TaurosWeb.AgentLive.Index do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Agents
        <:actions>
          <.button variant="primary" navigate={~p"/agents/new"}>
            <.icon name="hero-plus" /> New Agent
          </.button>
        </:actions>
      </.header>

      <.table
        id="agents"
        rows={@streams.agents}
        row_click={fn {_id, agent} -> JS.navigate(~p"/agents/#{agent}") end}
      >
        <:col :let={{_id, agent}} label="Name">{agent.name}</:col>

        <:col :let={{_id, agent}} label="Id" class="hidden sm:table-cell">{agent.id}</:col>

        <:col :let={{_id, agent}} label="Created at" class="hidden sm:table-cell">
          {agent.inserted_at}
        </:col>

        <:action :let={{_id, agent}}>
          <div class="sr-only">
            <.link navigate={~p"/agents/#{agent}"}>Show</.link>
          </div>

          <.link navigate={~p"/agents/#{agent}/edit"}>Edit</.link>
        </:action>

        <:action :let={{_id, agent}}>
          <.link
            phx-click={JS.push("delete", value: %{id: agent.id})}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <p :if={@empty?} id="empty-state" class="py-8 text-center opacity-70">
        No agents yet. Create one to get started.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Agents")
     |> assign_new(:current_user, fn -> nil end)
     |> stream_agents()}
  end

  defp stream_agents(socket) do
    agents = Tauros.Accounts.list_agents!(actor: socket.assigns.current_user)

    socket
    |> assign(:empty?, agents == [])
    |> stream(:agents, agents, reset: true)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    with {:ok, agent} <- Tauros.Accounts.get_agent(id, actor: actor),
         {:destroy, :ok} <- {:destroy, Tauros.Accounts.destroy_agent(agent, actor: actor)} do
      {:noreply, stream_agents(socket)}
    else
      # Destroying only fails validation when the agent still owns records.
      {:destroy, {:error, %Ash.Error.Invalid{}}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "An agent with customers, payment destinations or invoices cannot be deleted"
         )}

      _error ->
        {:noreply, put_flash(socket, :error, "The agent could not be deleted")}
    end
  end
end
