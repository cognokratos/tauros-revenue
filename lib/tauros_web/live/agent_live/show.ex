defmodule TaurosWeb.AgentLive.Show do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        {@agent.name}
        <:subtitle>Agent {@agent.id}</:subtitle>

        <:actions>
          <.button navigate={~p"/agents"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            id="rotate-api-key"
            phx-click="rotate_api_key"
            data-confirm="The current key stops working immediately. Continue?"
          >
            <.icon name="hero-key" /> Rotate API key
          </.button>
          <.button variant="primary" navigate={~p"/agents/#{@agent}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Agent
          </.button>
        </:actions>
      </.header>

      <.api_key_notice :if={@api_key} api_key={@api_key} />

      <.list>
        <:item title="Id">{@agent.id}</:item>

        <:item title="Name">{@agent.name}</:item>

        <:item title="Created"><.datetime value={@agent.inserted_at} /></:item>

        <:item title="Updated at">{@agent.updated_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Agent")
     |> assign(:api_key, nil)
     |> assign(:agent, Tauros.Accounts.get_agent!(id, actor: socket.assigns.current_user))}
  end

  @impl true
  def handle_event("rotate_api_key", _params, socket) do
    agent =
      Tauros.Accounts.rotate_agent_api_key!(socket.assigns.agent,
        actor: socket.assigns.current_user
      )

    {:noreply, assign(socket, agent: agent, api_key: agent.__metadata__.plaintext_api_key)}
  end
end
