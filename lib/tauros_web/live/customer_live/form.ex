defmodule TaurosWeb.CustomerLive.Form do
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        {@page_title}
        <:subtitle>Every customer belongs to exactly one of your agents.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="customer-form"
        phx-change="validate"
        phx-submit="save"
      >
        <%= if @form.source.type == :create do %>
          <.input field={@form[:name]} type="text" label="Name" /><.input
            field={@form[:email]}
            type="email"
            label="Email"
          /><.input
            field={@form[:agent_id]}
            type="select"
            label="Agent"
            prompt="Select an agent..."
            options={Enum.map(@agents, &{&1.name, &1.id})}
          />
        <% end %>
        <%= if @form.source.type == :update do %>
          <.input field={@form[:name]} type="text" label="Name" /><.input
            field={@form[:email]}
            type="email"
            label="Email"
          />
          <p id="customer-agent" class="text-sm opacity-70">
            Owned by agent <span class="font-semibold">{@customer.agent.name}</span>.
            Ownership cannot be reassigned.
          </p>
        <% end %>

        <.button phx-disable-with="Saving..." variant="primary">Save Customer</.button>
        <.button navigate={return_path(@return_to, @customer)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    customer =
      case params["id"] do
        nil ->
          nil

        id ->
          Tauros.Revenue.get_customer!(id, actor: socket.assigns.current_user, load: :agent)
      end

    action = if is_nil(customer), do: "New", else: "Edit"
    page_title = action <> " " <> "Customer"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(customer: customer)
     |> assign(:agents, Tauros.Accounts.list_agents!(actor: socket.assigns.current_user))
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: customer_params) do
      {:ok, customer} ->
        socket =
          socket
          |> put_flash(:info, "Customer #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, customer))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{customer: customer}} = socket) do
    form =
      if customer do
        AshPhoenix.Form.for_update(customer, :update,
          as: "customer",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Tauros.Revenue.Customer, :create,
          as: "customer",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _customer), do: ~p"/customers"
  defp return_path("show", customer), do: ~p"/customers/#{customer.id}"
end
