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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-base-300 bg-base-100">
      <div class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1 items-center gap-6">
          <.link navigate={~p"/"} class="flex items-center gap-2">
            <img src={~p"/images/logo.png"} alt="Tauros" class="h-8 w-auto" />
          </.link>
          <nav :if={@current_user} aria-label="Main navigation" class="hidden gap-1 md:flex">
            <.link :for={{label, path} <- nav_links()} navigate={path} class="btn btn-ghost btn-sm">
              {label}
            </.link>
          </nav>
        </div>
        <div class="flex flex-none items-center gap-2 sm:gap-4">
          <.theme_toggle />
          <span :if={@current_user} class="hidden text-sm opacity-70 lg:block">
            {@current_user.email} · {@current_user.role}
          </span>
          <.link
            :if={@current_user && @current_user.role == :approver}
            navigate={~p"/invite"}
            class="btn btn-ghost btn-sm hidden md:inline-flex"
          >
            Invite
          </.link>
          <.link
            :if={@current_user}
            href={~p"/sign-out"}
            method="delete"
            class="btn btn-ghost btn-sm hidden md:inline-flex"
          >
            Sign out
          </.link>
          <button
            :if={@current_user}
            id="mobile-menu-button"
            type="button"
            class="btn btn-ghost btn-square md:hidden"
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
        class="hidden border-t border-base-300 px-4 pb-4 md:hidden"
      >
        <ul class="menu w-full gap-1 px-0">
          <li :for={{label, path} <- nav_links()}>
            <.link navigate={path} class="min-h-11 text-base">{label}</.link>
          </li>
        </ul>
        <div class="mt-2 flex items-center justify-between gap-2 border-t border-base-300 pt-3">
          <span class="truncate text-sm opacity-70">{@current_user.email}</span>
          <.link href={~p"/sign-out"} method="delete" class="btn btn-ghost btn-sm">Sign out</.link>
        </div>
      </nav>
    </header>

    <main class="px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
      <div class="mx-auto max-w-5xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  defp nav_links do
    [
      {"Dashboard", ~p"/"},
      {"Approvals", ~p"/approvals"},
      {"Invoices", ~p"/invoices"},
      {"Agents", ~p"/agents"},
      {"Customers", ~p"/customers"},
      {"Destinations", ~p"/destinations"}
    ]
  end

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
