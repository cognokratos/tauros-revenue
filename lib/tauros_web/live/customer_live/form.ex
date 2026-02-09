defmodule TaurosWeb.CustomerLive.Form do
  use TaurosWeb, :live_view

  alias Tauros.Customers
  alias Tauros.Agents
  alias Tauros.Customers.Customer

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <.header>{@page_title}</.header>

        <.card>
          <div class="px-4 py-5 sm:p-6">
            <.form
              for={@form}
              id="customer-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-6"
            >
              <.input field={@form[:name]} type="text" label="Name" required />
              <.input field={@form[:email]} type="email" label="Email" required />
              <.input
                field={@form[:agent_id]}
                type="select"
                label="Agent"
                options={[{"Select an agent...", ""}] ++ Enum.map(@agents, &{&1.name, &1.id})}
                required={@live_action == :new}
                disabled={@live_action == :edit}
              />
              <div class="flex gap-4">
                <.button phx-disable-with="Saving..." variant="primary">Save Customer</.button>
                <.button navigate={return_path(@customer)} type="button">Cancel</.button>
              </div>
            </.form>
          </div>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:agents, Agents.list_agents(socket.assigns.current_scope))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    customer = Customers.get_customer!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(:customer, customer)
    |> assign(:form, to_form(Customers.change_customer(customer)))
  end

  defp apply_action(socket, :new, _params) do
    customer = %Customer{}

    socket
    |> assign(:page_title, "New Customer")
    |> assign(:customer, customer)
    |> assign(:form, to_form(Customers.change_customer(customer)))
  end

  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    changeset = Customers.change_customer(socket.assigns.customer, customer_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    save_customer(socket, socket.assigns.live_action, customer_params)
  end

  defp save_customer(socket, :edit, customer_params) do
    case Customers.update_customer(
           socket.assigns.current_scope,
           socket.assigns.customer,
           customer_params
         ) do
      {:ok, _customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer updated successfully")
         |> push_navigate(to: ~p"/customers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_customer(socket, :new, customer_params) do
    case Customers.create_customer(socket.assigns.current_scope, customer_params) do
      {:ok, _customer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer created successfully")
         |> push_navigate(to: ~p"/customers")}

      {:error, msg} when is_binary(msg) ->
        {:noreply, put_flash(socket, :error, msg)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(%Customer{id: nil}), do: ~p"/customers"
  defp return_path(%Customer{id: _id}), do: ~p"/customers"
end
