defmodule TaurosWeb.AgentLive.Show do
  use TaurosWeb, :live_view

  alias Tauros.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@agent.name}
        <:actions>
          <.button navigate={~p"/agents"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/agents/#{@agent}/edit"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <.card>
        <div class="px-4 py-5 sm:px-6">
          <.list>
            <:item title="ID">{@agent.id}</:item>
            <:item title="Name">{@agent.name}</:item>
            <:item title="Created">{format_datetime(@agent.inserted_at)}</:item>
          </.list>
        </div>
      </.card>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = Agents.get_agent!(id)

    {:ok,
     socket
     |> assign(:page_title, "Agent Details")
     |> assign(:agent, agent)}
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> to_string()
  end
end
