defmodule TaurosWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TaurosWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_user, :map, default: nil, doc: "the signed-in human, if any"

  attr :nav, :map,
    default: %{path: nil, needs_review: 0},
    doc: "current path and pending-review count, from `TaurosWeb.LiveUserAuth.assign_nav/1`"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :sections, nav_sections(assigns.current_user))

    ~H"""
    <header class="border-b border-base-300 bg-base-100">
      <div class="flex min-h-14 items-center gap-4 px-4 sm:px-6 lg:px-8">
        <.link navigate={~p"/"} class="flex shrink-0 items-center" aria-label="Tauros overview">
          <img src={~p"/images/logo.png"} alt="" class="h-8 w-auto" />
        </.link>

        <nav
          :if={@current_user}
          id="main-nav"
          aria-label="Main navigation"
          class="hidden flex-1 items-center gap-1 lg:flex"
        >
          <%= for {section, links} <- @sections do %>
            <span
              :if={section}
              class="mx-2 inline-block h-5 border-l border-base-300"
              aria-hidden="true"
            ></span>
            <.nav_link :for={link <- links} link={link} nav={@nav} />
          <% end %>
        </nav>

        <div class="ml-auto flex flex-none items-center gap-2 sm:gap-3">
          <.theme_toggle />
          <span :if={@current_user} class="hidden text-xs opacity-70 xl:block">
            {@current_user.email} · {@current_user.role}
          </span>
          <.link
            :if={@current_user}
            href={~p"/sign-out"}
            method="delete"
            class="btn btn-ghost btn-sm hidden lg:inline-flex"
          >
            Sign out
          </.link>
          <.link
            :if={@current_user && @nav.needs_review > 0}
            id="mobile-needs-review"
            navigate={~p"/invoices/review"}
            class="badge badge-info gap-1 lg:hidden"
          >
            {@nav.needs_review} to review
          </.link>
          <button
            :if={@current_user}
            id="mobile-menu-button"
            type="button"
            class="btn btn-ghost btn-square lg:hidden"
            aria-label="Open main menu"
            aria-controls="mobile-menu"
            phx-click={
              JS.toggle(to: "#mobile-menu") |> JS.toggle_attribute({"aria-expanded", "true", "false"})
            }
            aria-expanded="false"
          >
            <.icon name="hero-bars-3" class="size-6" />
          </button>
        </div>
      </div>

      <nav
        :if={@current_user}
        id="mobile-menu"
        aria-label="Mobile navigation"
        class="hidden border-t border-base-300 px-4 pb-4 lg:hidden"
      >
        <div :for={{section, links} <- @sections} class="pt-3">
          <p :if={section} class="px-3 pb-1 text-xs font-semibold uppercase tracking-wide opacity-60">
            {section}
          </p>
          <ul class="menu w-full gap-1 p-0">
            <li :for={link <- links}><.nav_link link={link} nav={@nav} mobile /></li>
          </ul>
        </div>
        <div class="mt-3 flex items-center justify-between gap-2 border-t border-base-300 pt-3">
          <span class="truncate text-sm opacity-70">
            {@current_user.email} · {@current_user.role}
          </span>
          <.link href={~p"/sign-out"} method="delete" class="btn btn-ghost btn-sm">Sign out</.link>
        </div>
      </nav>
    </header>

    <main class="px-4 py-8 sm:px-6 sm:py-10 lg:px-8">
      <div class="mx-auto max-w-6xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :link, :map, required: true
  attr :nav, :map, required: true
  attr :mobile, :boolean, default: false

  defp nav_link(assigns) do
    assigns = assign(assigns, :active?, active?(assigns.link, assigns.nav.path))

    ~H"""
    <.link
      navigate={@link.path}
      id={"nav-#{@link.id}#{if @mobile, do: "-mobile"}"}
      aria-current={@active? && "page"}
      class={[
        @mobile && "min-h-11 text-base",
        !@mobile && "btn btn-ghost btn-sm font-medium",
        @active? && "bg-base-200 font-semibold"
      ]}
    >
      {@link.label}
      <span
        :if={@link[:badge] == :needs_review and @nav.needs_review > 0}
        id={"nav-needs-review-count#{if @mobile, do: "-mobile"}"}
        class="badge badge-sm badge-info"
      >
        {@nav.needs_review}<span class="sr-only"> waiting</span>
      </span>
    </.link>
    """
  end

  # Navigation is organized around what a human does, not around tables:
  # the revenue workflow first, then the records agents work with.
  defp nav_sections(nil), do: []

  defp nav_sections(user) do
    [
      {nil, [%{id: "overview", label: "Overview", path: ~p"/", exact: true}]},
      {"Revenue",
       [
         %{
           id: "needs-review",
           label: "Needs review",
           path: ~p"/invoices/review",
           badge: :needs_review
         },
         %{id: "invoices", label: "Invoices", path: ~p"/invoices"}
       ]},
      {"Business",
       [
         %{id: "customers", label: "Customers", path: ~p"/customers"},
         %{id: "destinations", label: "Destinations", path: ~p"/destinations"}
       ]},
      {"Automation", [%{id: "agents", label: "Agents", path: ~p"/agents"}]}
    ] ++
      if user.role == :approver,
        do: [{"Admin", [%{id: "invite", label: "Invite", path: ~p"/invite"}]}],
        else: []
  end

  defp active?(_link, nil), do: false
  defp active?(%{exact: true, path: path}, current), do: current == path

  defp active?(%{id: "invoices"}, current),
    do: String.starts_with?(current, "/invoices") and not String.ends_with?(current, "/review")

  defp active?(%{id: "needs-review"}, current), do: String.ends_with?(current, "/review")
  defp active?(%{path: path}, current), do: String.starts_with?(current, path)

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
