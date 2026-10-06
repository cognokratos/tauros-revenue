defmodule TaurosWeb.InviteLive do
  @moduledoc "Approvers invite humans. Registration is otherwise closed."
  use TaurosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} nav={@nav}>
      <.header>
        Invite a human
        <:subtitle>
          Registration is closed. An invited human signs in with a magic link, or sets a password
          through "Forgot your password?".
        </:subtitle>
      </.header>

      <%= if @can_invite? do %>
        <.form for={@form} id="invite-form" phx-change="validate" phx-submit="invite">
          <.input field={@form[:email]} type="email" label="Email" />
          <.input
            field={@form[:role]}
            type="select"
            label="Role"
            options={[
              {"Operator: manages agents and customers, cannot approve", "operator"},
              {"Approver: may also approve financial proposals", "approver"}
            ]}
          />
          <.button phx-disable-with="Inviting..." variant="primary">Send invitation</.button>
        </.form>
      <% else %>
        <p id="invite-forbidden" class="rounded-box border border-base-300 p-4 text-sm">
          Only approvers can invite humans. Your role is {@current_user.role}.
        </p>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Invite a human")
     |> assign(:can_invite?, Ash.can?({Tauros.Accounts.User, :invite}, actor))
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("invite", %{"user" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invited #{user.email} as #{user.role}")
         |> assign_form()}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(socket) do
    form =
      AshPhoenix.Form.for_create(Tauros.Accounts.User, :invite,
        as: "user",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end
end
