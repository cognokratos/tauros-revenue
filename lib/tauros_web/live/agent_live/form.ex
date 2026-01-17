defmodule TaurosWeb.AgentLive.Form do
  use TaurosWeb, :live_view

  alias Tauros.Agents
  alias Tauros.Agents.Agent

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
      </.header>

      <.form for={@form} id="agent-form" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Agent Name" required />
        <.input
          field={@form[:api_key]}
          type="password"
          label="API Key (from external service)"
          required
          autocomplete="off"
          phx-debounce="blur"
        />
        <footer class="flex gap-2">
          <.button phx-disable-with="Saving..." variant="primary">
            {if @form.source.data.id, do: "Update", else: "Create"} Agent
          </.button>
          <.button navigate={~p"/agents"}>
            Cancel
          </.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Register New Agent")
    |> assign(:agent, %Agent{})
    |> assign(:form, to_form(Agents.change_agent(%Agent{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    agent = Agents.get_agent!(id)

    socket
    |> assign(:page_title, "Edit Agent")
    |> assign(:agent, agent)
    |> assign(:form, to_form(Agents.change_agent(agent)))
  end

  @impl true
  def handle_event("save", %{"agent" => agent_params}, socket) do
    current_scope = socket.assigns.current_scope

    case socket.assigns.live_action do
      :new ->
        case Agents.create_agent(current_scope, agent_params) do
          {:ok, _agent} ->
            {:noreply,
             socket
             |> put_flash(:info, "Agent registered successfully")
             |> push_navigate(to: ~p"/agents")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      :edit ->
        case Agents.update_agent(socket.assigns.agent, agent_params) do
          {:ok, _agent} ->
            {:noreply,
             socket
             |> put_flash(:info, "Agent updated successfully")
             |> push_navigate(to: ~p"/agents")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end
end
