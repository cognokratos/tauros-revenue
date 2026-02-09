defmodule TaurosWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TaurosWeb, :html
  alias Phoenix.LiveView.JS

  # Embed all files in layouts/* within this module.
  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil, doc: "the current scope"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-full">
      <nav
        aria-label="Main navigation"
        class="border-b border-gray-200 bg-white dark:border-white/10 dark:bg-gray-900"
      >
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 justify-between">
            <div class="flex">
              <div class="flex shrink-0 items-center">
                <img src={~p"/images/logo.png"} alt="Tauros" class="h-8 w-auto dark:hidden" />
                <img src={~p"/images/logo.png"} alt="Tauros" class="h-8 w-auto not-dark:hidden" />
              </div>

              <div class="hidden sm:-my-px sm:ml-6 sm:flex sm:space-x-8">
                <.link
                  navigate={~p"/"}
                  data-path="/"
                  class="relative inline-flex items-center border-b-2 border-transparent px-1 pt-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:border-white/20 dark:hover:text-gray-200"
                >
                  <span class="flex items-center">Dashboard</span>
                  <span
                    data-underline
                    class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
                    aria-hidden="true"
                  >
                  </span>
                </.link>
                <.link
                  navigate={~p"/agents"}
                  data-path="/agents"
                  class="relative inline-flex items-center border-b-2 border-transparent px-1 pt-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:border-white/20 dark:hover:text-gray-200"
                >
                  <span class="flex items-center">Agents</span>
                  <span
                    data-underline
                    class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
                    aria-hidden="true"
                  >
                  </span>
                </.link>
                <.link
                  navigate={~p"/customers"}
                  data-path="/customers"
                  class="relative inline-flex items-center border-b-2 border-transparent px-1 pt-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:border-white/20 dark:hover:text-gray-200"
                >
                  <span class="flex items-center">Customers</span>
                  <span
                    data-underline
                    class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
                    aria-hidden="true"
                  >
                  </span>
                </.link>
              </div>
            </div>

            <div class="hidden sm:ml-6 sm:flex sm:items-center gap-4">
              <.theme_toggle />

              <%= if @current_scope do %>
                <div class="relative group">
                  <button class="relative flex max-w-xs items-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:focus-visible:outline-indigo-500">
                    <span class="absolute -inset-1.5 pointer-events-none"></span>
                    <span class="sr-only">Open user menu</span>
                    <div class="size-8 rounded-full outline -outline-offset-1 outline-black/5 dark:outline-white/10 bg-indigo-600 flex items-center justify-center text-white text-sm font-medium">
                      {initials(@current_scope.user.email)}
                    </div>
                  </button>

                  <div class="absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white py-1 shadow-lg outline outline-black/5 dark:bg-gray-800 dark:shadow-none dark:-outline-offset-1 dark:outline-white/10 opacity-0 invisible group-hover:opacity-100 group-hover:visible group-focus-within:opacity-100 group-focus-within:visible transition-all duration-200">
                    <div class="px-4 py-2 text-sm text-gray-700 dark:text-gray-300 border-b border-gray-200 dark:border-gray-700">
                      {@current_scope.user.email}
                    </div>
                    <.link
                      href={~p"/users/settings"}
                      class="block px-4 py-2 text-sm text-gray-700 dark:text-gray-300 border-b border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-white/5"
                    >
                      Settings
                    </.link>
                    <.link
                      href={~p"/users/log-out"}
                      method="delete"
                      class="block px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/5"
                    >
                      Log out
                    </.link>
                  </div>
                </div>
              <% else %>
                <.link
                  href={~p"/users/register"}
                  class="text-sm font-medium text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                >
                  Register
                </.link>
                <.link
                  href={~p"/users/log-in"}
                  class="text-sm font-medium text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                >
                  Log in
                </.link>
              <% end %>
            </div>

            <div class="-mr-2 flex items-center sm:hidden">
              <button
                type="button"
                phx-click={
                  JS.toggle(
                    to: "#mobile-menu",
                    in:
                      {"transition ease-out duration-200", "opacity-0 scale-95",
                       "opacity-100 scale-100"},
                    out:
                      {"transition ease-in duration-150", "opacity-100 scale-100",
                       "opacity-0 scale-95"}
                  )
                }
                aria-expanded="false"
                aria-controls="mobile-menu"
                class="relative inline-flex items-center justify-center rounded-md bg-white p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-500 focus:outline-2 focus:outline-offset-2 focus:outline-indigo-600 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white dark:focus:outline-indigo-500"
              >
                <span class="absolute -inset-0.5"></span>
                <span class="sr-only">Open main menu</span>
                <.icon name="hero-bars-3" class="size-6" />
              </button>
            </div>
          </div>
        </div>
      </nav>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".NavHighlight">
        export default {
          mounted() {
            const setActive = () => {
              const path = location.pathname
              const nav = document.querySelector('nav')
              if(!nav) return
              for (const a of nav.querySelectorAll('a[data-path]')) {
                const href = a.getAttribute('data-path')
                const underline = a.querySelector('[data-underline]')
                if (href === path) {
                  a.setAttribute('aria-current', 'page')
                  a.classList.add('border-indigo-600', 'text-gray-900')
                  a.classList.remove('border-transparent', 'text-gray-500')
                  if (underline) { underline.classList.remove('scale-x-0'); underline.classList.add('scale-x-100') }
                } else {
                  a.removeAttribute('aria-current')
                  a.classList.remove('border-indigo-600', 'text-gray-900')
                  a.classList.add('border-transparent', 'text-gray-500')
                  if (underline) { underline.classList.remove('scale-x-100'); underline.classList.add('scale-x-0') }
                }
              }

              // ensure mobile menu closes on navigation
              const menu = document.getElementById('mobile-menu')
              const toggle = document.querySelector('button[aria-controls="mobile-menu"]')
              if (menu && !menu.classList.contains('hidden')) {
                menu.classList.add('hidden')
                if (toggle) toggle.setAttribute('aria-expanded', 'false')
              }
            }

            setActive()
            window.addEventListener('popstate', setActive)
            document.addEventListener('phx:page-loading-stop', setActive)
            document.addEventListener('click', () => setActive())

            // close mobile menu when a nav link is clicked
            const nav = document.querySelector('nav')
            if (nav) {
              for (const a of nav.querySelectorAll('a[data-path]')) {
                a.addEventListener('click', () => {
                  const menu = document.getElementById('mobile-menu')
                  const toggle = document.querySelector('button[aria-controls="mobile-menu"]')
                  if (menu) menu.classList.add('hidden')
                  if (toggle) toggle.setAttribute('aria-expanded', 'false')
                })
              }
            }
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".MobileToggle">
        export default {
          mounted() {
            const btn = document.querySelector('button[aria-controls="mobile-menu"]')
            const menu = document.getElementById('mobile-menu')
            if (!btn) return
            const update = () => {
              const open = menu && !menu.classList.contains('hidden')
              btn.setAttribute('aria-expanded', open ? 'true' : 'false')
            }
            btn.addEventListener('click', () => setTimeout(update, 0))
            update()
          }
        }
      </script>

      <div
        id="mobile-menu"
        class="hidden sm:hidden fixed inset-x-0 top-16 z-40 w-full bg-white dark:bg-gray-800/95 backdrop-blur-sm shadow-lg max-h-[calc(100vh-4rem)] overflow-auto"
      >
        <div class="space-y-1 pt-4 pb-3 px-4">
          <.link
            navigate={~p"/"}
            data-path="/"
            class="relative block border-l-4 border-transparent py-2 pr-4 pl-3 text-base font-medium text-gray-600 hover:border-gray-300 hover:bg-gray-50 hover:text-gray-800 dark:text-gray-400 dark:hover:border-gray-500 dark:hover:bg-white/5 dark:hover:text-gray-200"
          >
            <span class="flex items-center">Dashboard</span>
            <span
              data-underline
              class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
              aria-hidden="true"
            >
            </span>
          </.link>
          <.link
            navigate={~p"/agents"}
            data-path="/agents"
            class="relative block border-l-4 border-transparent py-2 pr-4 pl-3 text-base font-medium text-gray-600 hover:border-gray-300 hover:bg-gray-50 hover:text-gray-800 dark:text-gray-400 dark:hover:border-gray-500 dark:hover:bg-white/5 dark:hover:text-gray-200"
          >
            <span class="flex items-center">Agents</span>
            <span
              data-underline
              class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
              aria-hidden="true"
            >
            </span>
          </.link>
          <.link
            navigate={~p"/customers"}
            data-path="/customers"
            class="relative block border-l-4 border-transparent py-2 pr-4 pl-3 text-base font-medium text-gray-600 hover:border-gray-300 hover:bg-gray-50 hover:text-gray-800 dark:text-gray-400 dark:hover:border-gray-500 dark:hover:bg-white/5 dark:hover:text-gray-200"
          >
            <span class="flex items-center">Customers</span>
            <span
              data-underline
              class="absolute left-0 -bottom-1 h-0.5 w-full bg-indigo-600 transform scale-x-0 origin-left transition-transform duration-200"
              aria-hidden="true"
            >
            </span>
          </.link>
        </div>

        <div class="border-t border-gray-200 pt-4 pb-3 dark:border-gray-700">
          <div class="flex items-center px-4">
            <div class="shrink-0">
              <div class="size-10 rounded-full outline -outline-offset-1 outline-black/5 dark:outline-white/10 bg-indigo-600 flex items-center justify-center text-white text-sm font-medium">
                {initials((@current_scope && @current_scope.user.email) || "")}
              </div>
            </div>
            <div class="ml-3">
              <div class="text-base font-medium text-gray-800 dark:text-white">
                {(@current_scope && @current_scope.user.email) || ""}
              </div>
            </div>
          </div>

          <div class="mt-3 space-y-1 px-2">
            <.link
              href={~p"/users/settings"}
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:bg-gray-100 hover:text-gray-800"
            >
              Settings
            </.link>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:bg-gray-100 hover:text-gray-800"
            >
              Log out
            </.link>
          </div>
        </div>
      </div>

      <div class="py-10">
        <main>
          <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 bg-white/90 dark:bg-black/90 rounded-lg">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp initials(email) do
    email
    |> String.split("@")
    |> List.first("")
    |> String.upcase()
    |> String.slice(0..1)
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
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
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

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
