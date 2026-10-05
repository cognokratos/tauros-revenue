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

        <:col :let={{_id, agent}} label="Id">{agent.id}</:col>

        <:col :let={{_id, agent}} label="Created at">{agent.inserted_at}</:col>

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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Agents")
     |> assign_new(:current_user, fn -> nil end)
     |> stream(:agents, Tauros.Accounts.list_agents!(actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agent = Ash.get!(Tauros.Accounts.Agent, id, actor: socket.assigns.current_user)

    case Ash.destroy(agent, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, stream_delete(socket, :agents, agent)}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "An agent with customers or wallet accounts cannot be deleted")}
    end
  end
end
