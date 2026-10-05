defmodule TaurosWeb.AgentLive.Form do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@page_title}
        <:subtitle>An agent acts on your behalf with its own API key.</:subtitle>
      </.header>

      <.api_key_notice :if={@api_key} api_key={@api_key}>
        <.button navigate={~p"/agents/#{@agent}"} variant="primary">Done</.button>
      </.api_key_notice>

      <.form
        :if={!@api_key}
        for={@form}
        id="agent-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <.button phx-disable-with="Saving..." variant="primary">Save Agent</.button>
        <.button navigate={return_path(@return_to, @agent)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    agent =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Tauros.Accounts.Agent, id, actor: socket.assigns.current_user)
      end

    action = if is_nil(agent), do: "New", else: "Edit"
    page_title = action <> " " <> "Agent"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(agent: agent, api_key: nil)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"agent" => agent_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, agent_params))}
  end

  def handle_event("save", %{"agent" => agent_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: agent_params) do
      {:ok, %{__metadata__: %{api_key: api_key}} = agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> assign(agent: agent, api_key: api_key)}

      {:ok, agent} ->
        socket =
          socket
          |> put_flash(:info, "Agent #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, agent))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{agent: agent}} = socket) do
    form =
      if agent do
        AshPhoenix.Form.for_update(agent, :update,
          as: "agent",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Tauros.Accounts.Agent, :create,
          as: "agent",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _agent), do: ~p"/agents"
  defp return_path("show", agent), do: ~p"/agents/#{agent.id}"
end
