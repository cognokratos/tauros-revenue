defmodule TaurosWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use TaurosWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {TaurosWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, assign_nav(socket)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  @doc """
  Navigation state for `Layouts.app`: the current path (for the active link)
  and how many proposals wait for a human decision (the "Needs review" badge).
  The count comes from the domain's `awaiting_approval` read, so policies
  decide what it includes. LiveViews that change it call this again.
  """
  def assign_nav(socket) do
    socket
    |> assign(:nav, %{
      path: socket.assigns[:nav][:path],
      needs_review: needs_review_count(socket.assigns.current_user)
    })
    |> Phoenix.LiveView.attach_hook(:nav_path, :handle_params, fn _params, uri, socket ->
      {:cont, assign(socket, :nav, %{socket.assigns.nav | path: URI.parse(uri).path})}
    end)
  end

  defp needs_review_count(user) do
    Tauros.Revenue.Invoice
    |> Ash.Query.for_read(:awaiting_approval, %{}, actor: user)
    |> Ash.count!()
  end
end
