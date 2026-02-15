defmodule FitconnexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FitconnexWeb, :html

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

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil, doc: "the current authenticated user"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :user_role, get_user_role(assigns[:current_user]))

    ~H"""
    <%= if @current_user do %>
      <div class="drawer lg:drawer-open" id="app-drawer">
        <input id="sidebar-toggle" type="checkbox" class="drawer-toggle" />

        <%!-- Main Content Area --%>
        <div class="drawer-content flex flex-col min-h-screen bg-base-100">
          <%!-- Top Navbar (mobile + desktop) --%>
          <header class="navbar bg-base-100 border-b border-base-300/50 px-4 lg:px-6 sticky top-0 z-30">
            <div class="flex-none lg:hidden">
              <label
                for="sidebar-toggle"
                class="btn btn-ghost btn-sm btn-square"
                aria-label="Open menu"
              >
                <.icon name="hero-bars-3" class="size-5" />
              </label>
            </div>
            <div class="flex-1 lg:flex-none">
              <h1 class="text-lg font-bold lg:hidden">
                Fit<span class="text-primary">Connex</span>
              </h1>
            </div>
            <div class="flex-1 hidden lg:block"></div>
            <div class="flex-none flex items-center gap-3">
              <.theme_toggle />
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2">
                  <div class="w-7 h-7 rounded-full bg-primary/15 flex items-center justify-center">
                    <span class="text-xs font-bold text-primary">
                      {String.first(@current_user.name || "U")}
                    </span>
                  </div>
                  <span class="hidden sm:inline text-sm font-medium">{@current_user.name}</span>
                  <.icon name="hero-chevron-down-mini" class="size-3 opacity-50" />
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content menu bg-base-200 rounded-box z-50 w-52 p-2 shadow-lg border border-base-300"
                >
                  <li class="menu-title text-xs">
                    {format_role(@user_role)}
                  </li>
                  <li>
                    <a href="/sign-out" class="text-error">
                      <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign Out
                    </a>
                  </li>
                </ul>
              </div>
            </div>
          </header>

          <%!-- Page Content --%>
          <main class="flex-1 p-4 sm:p-6 lg:p-8">
            <div class="max-w-7xl mx-auto">
              {render_slot(@inner_block)}
            </div>
          </main>
        </div>

        <%!-- Sidebar --%>
        <div class="drawer-side z-40">
          <label for="sidebar-toggle" aria-label="Close menu" class="drawer-overlay"></label>
          <aside class="w-72 min-h-full bg-base-200 border-r border-base-300/50 flex flex-col">
            <%!-- Sidebar Header --%>
            <div class="p-5 border-b border-base-300/50">
              <a href="/dashboard" class="text-2xl font-extrabold tracking-tight">
                Fit<span class="text-primary">Connex</span>
              </a>
              <p class="text-xs text-base-content/40 mt-1">{format_role(@user_role)} Portal</p>
            </div>

            <%!-- Navigation Links --%>
            <nav class="flex-1 p-4 space-y-1">
              <.sidebar_nav role={@user_role} />
            </nav>

            <%!-- Sidebar Footer --%>
            <div class="p-4 border-t border-base-300/50">
              <div class="flex items-center gap-3 px-3 py-2">
                <div class="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center shrink-0">
                  <span class="text-sm font-bold text-primary">
                    {String.first(@current_user.name || "U")}
                  </span>
                </div>
                <div class="min-w-0">
                  <p class="text-sm font-semibold truncate">{@current_user.name}</p>
                  <p class="text-xs text-base-content/50 truncate">{@current_user.email}</p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    <% else %>
      <%!-- Public layout (no sidebar) --%>
      <header class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="flex-1 flex w-fit items-center gap-2 text-xl font-bold">
            Fit<span class="text-primary">Connex</span>
          </a>
        </div>
        <div class="flex-none">
          <ul class="flex flex-column px-1 space-x-4 items-center">
            <li>
              <a href="/explore" class="btn btn-ghost btn-sm font-semibold">Explore Gyms</a>
            </li>
            <li>
              <.theme_toggle />
            </li>
            <li>
              <a href="/sign-in" class="btn btn-primary btn-sm">Sign In</a>
            </li>
          </ul>
        </div>
      </header>

      <main class="px-4 py-20 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-4xl space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders role-specific sidebar navigation links.
  """
  attr :role, :atom, required: true

  def sidebar_nav(%{role: :platform_admin} = assigns) do
    ~H"""
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Overview
    </p>
    <.nav_link href="/admin/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Management
    </p>
    <.nav_link href="/admin/users" icon="hero-user-group-solid" label="Users" />
    <.nav_link href="/admin/gyms" icon="hero-building-office-2-solid" label="Gyms" />
    """
  end

  def sidebar_nav(%{role: :gym_operator} = assigns) do
    ~H"""
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Overview
    </p>
    <.nav_link href="/gym/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Gym Management
    </p>
    <.nav_link href="/gym/setup" icon="hero-building-office-solid" label="My Gym" />
    <.nav_link href="/gym/branches" icon="hero-map-pin-solid" label="Branches" />
    <.nav_link href="/gym/members" icon="hero-user-group-solid" label="Members" />
    <.nav_link href="/gym/trainers" icon="hero-academic-cap-solid" label="Trainers" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Operations
    </p>
    <.nav_link href="/gym/classes" icon="hero-calendar-days-solid" label="Classes" />
    <.nav_link href="/gym/plans" icon="hero-credit-card-solid" label="Plans & Billing" />
    <.nav_link href="/gym/invitations" icon="hero-envelope-solid" label="Invitations" />
    <.nav_link href="/gym/attendance" icon="hero-clipboard-document-check-solid" label="Attendance" />
    """
  end

  def sidebar_nav(%{role: :trainer} = assigns) do
    ~H"""
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Overview
    </p>
    <.nav_link href="/trainer/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />
    <.nav_link href="/trainer/gyms" icon="hero-building-office-2-solid" label="My Gyms" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Clients
    </p>
    <.nav_link href="/trainer/clients" icon="hero-user-group-solid" label="My Clients" />
    <.nav_link
      href="/trainer/attendance"
      icon="hero-clipboard-document-check-solid"
      label="Attendance"
    />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Programs
    </p>
    <.nav_link href="/trainer/workouts" icon="hero-fire-solid" label="Workout Plans" />
    <.nav_link href="/trainer/diets" icon="hero-heart-solid" label="Diet Plans" />
    <.nav_link href="/trainer/templates" icon="hero-document-duplicate-solid" label="Templates" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Schedule
    </p>
    <.nav_link href="/trainer/classes" icon="hero-calendar-days-solid" label="My Classes" />
    """
  end

  def sidebar_nav(assigns) do
    ~H"""
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Overview
    </p>
    <.nav_link href="/member/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />
    <.nav_link href="/member/gym" icon="hero-building-office-2-solid" label="My Gyms" />
    <.nav_link href="/member/trainer" icon="hero-academic-cap-solid" label="My Trainer" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Fitness
    </p>
    <.nav_link href="/member/workout" icon="hero-fire-solid" label="My Workout" />
    <.nav_link href="/member/diet" icon="hero-heart-solid" label="My Diet Plan" />
    <.nav_link
      href="/member/attendance"
      icon="hero-clipboard-document-check-solid"
      label="Attendance"
    />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Classes
    </p>
    <.nav_link href="/member/classes" icon="hero-calendar-days-solid" label="Browse Classes" />
    <.nav_link href="/member/bookings" icon="hero-ticket-solid" label="My Bookings" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Account
    </p>
    <.nav_link href="/member/subscription" icon="hero-credit-card-solid" label="Subscription" />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-base-content/70 hover:text-base-content hover:bg-base-300/50"
    >
      <.icon name={@icon} class="size-5 shrink-0" />
      <span>{@label}</span>
    </a>
    """
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

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
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

  @doc """
  A browser-history back button.
  """
  def back_button(assigns) do
    ~H"""
    <button onclick="history.back()" class="btn btn-ghost btn-sm btn-circle" aria-label="Go back">
      <.icon name="hero-arrow-left" class="size-5" />
    </button>
    """
  end

  defp get_user_role(nil), do: :member
  defp get_user_role(%{role: role}) when is_atom(role), do: role
  defp get_user_role(%{role: role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(_), do: :member

  defp format_role(:platform_admin), do: "Platform Admin"
  defp format_role(:gym_operator), do: "Gym Operator"
  defp format_role(:trainer), do: "Trainer"
  defp format_role(:member), do: "Member"
  defp format_role(_), do: "Member"
end
