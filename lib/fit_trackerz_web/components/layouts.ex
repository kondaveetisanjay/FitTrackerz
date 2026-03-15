defmodule FitTrackerzWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FitTrackerzWeb, :html

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
          <%!-- Top Navbar --%>
          <header class="navbar bg-base-100/80 backdrop-blur-xl border-b border-base-300/30 px-4 lg:px-8 sticky top-0 z-30">
            <div class="flex-none lg:hidden">
              <label
                for="sidebar-toggle"
                class="btn btn-ghost btn-sm btn-square hover:bg-primary/10"
                aria-label="Open menu"
              >
                <.icon name="hero-bars-3" class="size-5" />
              </label>
            </div>
            <div class="flex-1 lg:flex-none lg:hidden">
              <.brand_logo class="h-9 w-auto" />
            </div>
            <div class="flex-1 hidden lg:block"></div>
            <div class="flex-none flex items-center gap-3">
              <.theme_toggle />
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2 rounded-xl hover:bg-primary/8">
                  <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center ring-2 ring-primary/10">
                    <span class="text-xs font-bold text-primary">
                      {String.first(@current_user.name || "U")}
                    </span>
                  </div>
                  <div class="hidden sm:block text-left">
                    <span class="text-sm font-semibold block leading-tight">{@current_user.name}</span>
                    <span class="text-[10px] text-base-content/40">{format_role(@user_role)}</span>
                  </div>
                  <.icon name="hero-chevron-down-mini" class="size-3 opacity-40" />
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content menu bg-base-100 rounded-xl z-50 w-56 p-2 shadow-xl border border-base-300/50 mt-2"
                >
                  <li class="menu-title text-xs px-3 py-1 text-base-content/40">
                    {format_role(@user_role)} Portal
                  </li>
                  <li>
                    <.link href="/sign-out" class="text-error hover:bg-error/10 rounded-lg gap-2">
                      <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign Out
                    </.link>
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
          <aside class="w-72 min-h-full bg-base-200/80 backdrop-blur-xl border-r border-base-300/30 flex flex-col relative">
            <%!-- Sidebar gradient accent --%>
            <div class="absolute left-0 top-0 bottom-0 w-[3px] bg-gradient-to-b from-primary via-secondary to-primary/30"></div>

            <%!-- Sidebar Header --%>
            <div class="p-5 pl-6 border-b border-base-300/30">
              <.link navigate="/dashboard" class="flex items-center gap-2">
                <.brand_logo class="h-10 w-auto" />
              </.link>
              <div class="flex items-center gap-2 mt-2">
                <div class="w-1.5 h-1.5 rounded-full bg-success animate-pulse"></div>
                <p class="text-[11px] text-base-content/40 font-medium tracking-wide uppercase">
                  {format_role(@user_role)} Portal
                </p>
              </div>
            </div>

            <%!-- Navigation Links --%>
            <nav class="flex-1 p-4 pl-5 space-y-0.5 overflow-y-auto" id="sidebar-nav" phx-hook="ActiveNav">
              <.sidebar_nav role={@user_role} />
            </nav>

            <%!-- Sidebar Footer --%>
            <div class="p-4 pl-5 border-t border-base-300/30">
              <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-base-300/30">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center shrink-0 ring-1 ring-primary/10">
                  <span class="text-sm font-bold text-primary">
                    {String.first(@current_user.name || "U")}
                  </span>
                </div>
                <div class="min-w-0">
                  <p class="text-sm font-semibold truncate">{@current_user.name}</p>
                  <p class="text-[11px] text-base-content/40 truncate">{@current_user.email}</p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    <% else %>
      <%!-- Public layout (no sidebar) --%>
      <header class="navbar px-4 sm:px-6 lg:px-8 bg-base-100/80 backdrop-blur-xl sticky top-0 z-50 border-b border-base-300/20">
        <div class="flex-1">
          <.link navigate="/" class="flex-1 flex w-fit items-center gap-2">
            <.brand_logo class="h-10 w-auto" />
          </.link>
        </div>
        <div class="flex-none">
          <ul class="flex flex-column px-1 gap-1 items-center">
            <li>
              <.link navigate="/explore" class="btn btn-ghost btn-sm font-semibold rounded-lg hover:bg-primary/8">
                Explore Gyms
              </.link>
            </li>
            <li>
              <.link navigate="/explore/contests" class="btn btn-ghost btn-sm font-semibold rounded-lg hover:bg-primary/8">
                Contests
              </.link>
            </li>
            <li>
              <.theme_toggle />
            </li>
            <li>
              <.link navigate="/sign-in" class="btn btn-primary btn-sm rounded-lg font-bold shadow-md shadow-primary/20">
                Sign In
              </.link>
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
    <.nav_section label="Overview" />
    <.nav_link href="/admin/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />

    <.nav_section label="Management" />
    <.nav_link href="/admin/users" icon="hero-user-group-solid" label="Users" />
    <.nav_link href="/admin/gyms" icon="hero-building-office-2-solid" label="Gyms" />
    """
  end

  def sidebar_nav(%{role: :gym_operator} = assigns) do
    ~H"""
    <.nav_section label="Overview" />
    <.nav_link href="/gym/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />

    <.nav_section label="Gym Management" />
    <.nav_link href="/gym/setup" icon="hero-building-office-solid" label="My Gym" />
    <.nav_link href="/gym/members" icon="hero-user-group-solid" label="Members" />

    <.nav_section label="Operations" />
    <.nav_link href="/gym/classes" icon="hero-calendar-days-solid" label="Classes" />
    <.nav_link href="/gym/plans" icon="hero-credit-card-solid" label="Plans & Billing" />
    <.nav_link href="/gym/invitations" icon="hero-envelope-solid" label="Invitations" />
    <.nav_link href="/gym/attendance" icon="hero-clipboard-document-check-solid" label="Attendance" />
    <.nav_link href="/gym/contests" icon="hero-trophy-solid" label="Contests" />
    """
  end

  def sidebar_nav(assigns) do
    ~H"""
    <.nav_section label="Overview" />
    <.nav_link href="/member/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />
    <.nav_link href="/member/gym" icon="hero-building-office-2-solid" label="My Gyms" />

    <.nav_section label="Fitness" />
    <.nav_link href="/member/workout" icon="hero-fire-solid" label="My Workout" />
    <.nav_link href="/member/diet" icon="hero-heart-solid" label="My Diet Plan" />
    <.nav_link
      href="/member/attendance"
      icon="hero-clipboard-document-check-solid"
      label="Attendance"
    />

    <.nav_section label="Classes" />
    <.nav_link href="/member/classes" icon="hero-calendar-days-solid" label="Browse Classes" />
    <.nav_link href="/member/bookings" icon="hero-ticket-solid" label="My Bookings" />

    <.nav_section label="Account" />
    <.nav_link href="/member/subscription" icon="hero-credit-card-solid" label="Subscription" />
    """
  end

  attr :label, :string, required: true

  defp nav_section(assigns) do
    ~H"""
    <div class="pt-5 pb-2 first:pt-0">
      <div class="flex items-center gap-2 px-3">
        <p class="text-[10px] font-bold text-base-content/30 uppercase tracking-widest">
          {@label}
        </p>
        <div class="flex-1 h-px bg-base-300/30"></div>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-base-content/60 hover:text-base-content hover:bg-base-300/40 transition-all duration-200 data-[active=true]:bg-primary/10 data-[active=true]:text-primary data-[active=true]:font-semibold"
    >
      <div class="w-8 h-8 rounded-lg bg-base-300/30 flex items-center justify-center transition-colors group-hover:bg-primary/10 group-data-[active=true]:bg-primary/15">
        <.icon name={@icon} class="size-4 transition-colors group-hover:text-primary group-data-[active=true]:text-primary" />
      </div>
      <span>{@label}</span>
    </.link>
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
    <button
      onclick="history.back()"
      class="btn btn-ghost btn-sm btn-circle hover:bg-primary/10"
      aria-label="Go back"
    >
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
  defp format_role(:member), do: "Member"
  defp format_role(_), do: "Member"
end
