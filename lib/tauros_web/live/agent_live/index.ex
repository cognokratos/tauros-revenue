defmodule TaurosWeb.AgentLive.Index do
  use TaurosWeb, :live_view

  alias Tauros.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Agents
        <:actions>
          <.button variant="primary" navigate={~p"/agents/new"}>
            <.icon name="hero-plus" /> New Agent
          </.button>
        </:actions>
      </.header>

      <div id="agents" phx-update="stream" class="space-y-4">
        <div id="empty-state" style="display: none">
          <div class="text-center py-8 text-gray-500">
            No agents yet. Create one to get started.
          </div>
        </div>
        <%= for {id, agent} <- @streams.agents do %>
          <div id={id} class="border rounded-lg p-4">
            <div class="flex items-start justify-between">
              <div>
                <h3 class="font-semibold text-lg">{agent.name}</h3>
                <p class="text-gray-600 text-sm">ID: {agent.id}</p>
              </div>
              <div class="space-x-2">
                <.link navigate={~p"/agents/#{agent}/edit"} class="text-blue-600 hover:text-blue-800">
                  Edit
                </.link>
                <.link
                  phx-click={JS.push("delete", value: %{id: agent.id}) |> hide("##{id}")}
                  data-confirm="Are you sure?"
                  class="text-red-600 hover:text-red-800"
                >
                  Delete
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns[:current_scope]

    {:ok,
     socket
     |> assign(:page_title, "Agents")
     |> stream(:agents, Agents.list_agents_for_user(current_scope.user.id))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agent = Agents.get_agent!(id)
    {:ok, _} = Agents.delete_agent(agent)

    {:noreply, stream_delete(socket, :agents, agent)}
  end
end
