defmodule FitTrackerzWeb.Layouts do
  @moduledoc """
  Layout components for FitTrackerz application shell.
  """
  use FitTrackerzWeb, :html

  embed_templates "layouts/*"

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
          <%!-- Gradient accent line --%>
          <div class="h-1 bg-gradient-to-r from-primary via-secondary to-accent animate-gradient-shift" style="background-size: 200% 100%;"></div>

          <%!-- Top Navbar --%>
          <header class="navbar bg-base-100/90 backdrop-blur-xl border-b border-base-200/60 px-4 lg:px-8 sticky top-0 z-30">
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
                  class="dropdown-content menu bg-base-100 rounded-xl z-50 w-56 p-2 shadow-xl border border-base-200/60 mt-2"
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
          <aside class="w-72 min-h-full bg-base-200/80 backdrop-blur-xl border-r border-base-300/30 flex flex-col relative overflow-hidden">
            <%!-- Sidebar ambient glow --%>
            <div class="absolute top-0 left-0 w-full h-48 bg-gradient-to-b from-primary/8 to-transparent pointer-events-none"></div>
            <div class="absolute bottom-0 left-0 w-full h-32 bg-gradient-to-t from-accent/5 to-transparent pointer-events-none"></div>

            <%!-- Sidebar Header --%>
            <div class="relative p-5 border-b border-base-300/30">
              <.link navigate="/dashboard" class="flex items-center gap-2">
                <.brand_logo class="h-10 w-auto" />
              </.link>
              <div class="flex items-center gap-2 mt-2.5">
                <div class="w-2 h-2 rounded-full bg-primary shadow-[0_0_8px] shadow-primary/50 animate-pulse"></div>
                <p class="text-[11px] text-base-content/50 font-bold tracking-widest uppercase">
                  {format_role(@user_role)} Portal
                </p>
              </div>
            </div>

            <%!-- Navigation Links --%>
            <nav class="flex-1 py-4 px-3 space-y-0.5 overflow-y-auto" id="sidebar-nav" phx-hook="ActiveNav">
              <.sidebar_nav role={@user_role} />
            </nav>

            <%!-- Sidebar Footer --%>
            <div class="relative p-4 border-t border-base-300/30">
              <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-base-300/30 hover:bg-base-300/50 transition-colors border border-base-300/20">
                <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-primary to-accent flex items-center justify-center shrink-0 shadow-[0_0_12px] shadow-primary/30">
                  <span class="text-sm font-bold text-white">
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
      <div class="h-1 bg-gradient-to-r from-primary via-secondary to-accent animate-gradient-shift" style="background-size: 200% 100%;"></div>
      <header class="navbar px-4 sm:px-6 lg:px-8 bg-base-100/90 backdrop-blur-xl sticky top-0 z-50 border-b border-base-200/40">
        <div class="flex-1">
          <.link navigate="/" class="flex-1 flex w-fit items-center gap-2">
            <.brand_logo class="h-10 w-auto" />
          </.link>
        </div>
        <div class="flex-none">
          <ul class="flex flex-column px-1 gap-1 items-center">
            <li class="hidden sm:block">
              <.link navigate="/explore" class="btn btn-ghost btn-sm font-semibold rounded-lg hover:bg-primary/8">
                Explore Gyms
              </.link>
            </li>
            <li class="hidden sm:block">
              <.link navigate="/explore/contests" class="btn btn-ghost btn-sm font-semibold rounded-lg hover:bg-primary/8">
                Contests
              </.link>
            </li>
            <li>
              <.theme_toggle />
            </li>
            <li>
              <.link navigate="/sign-in" class="btn btn-primary btn-sm rounded-lg font-bold shadow-md shadow-primary/20 press-scale">
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

  ## Sidebar Navigation

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
    <.nav_link href="/member/attendance" icon="hero-clipboard-document-check-solid" label="Attendance" />

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
    <div class="pt-6 pb-2 first:pt-1">
      <p class="text-[10px] font-bold text-base-content/30 uppercase tracking-[0.15em] px-3">
        {@label}
      </p>
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
      class="group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-base-content/50 hover:text-base-content hover:bg-primary/8 transition-all duration-200 data-[active=true]:bg-primary/12 data-[active=true]:text-primary data-[active=true]:font-bold data-[active=true]:shadow-[inset_3px_0_0] data-[active=true]:shadow-primary data-[active=true]:rounded-l-none"
    >
      <.icon name={@icon} class="size-[18px] transition-colors text-base-content/30 group-hover:text-primary/60 group-data-[active=true]:text-primary group-data-[active=true]:drop-shadow-[0_0_6px_var(--color-primary)]" />
      <span>{@label}</span>
    </.link>
    """
  end

  ## Flash Group

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

  ## Theme Toggle

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

  ## Back Button

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

  ## Helpers

  defp get_user_role(nil), do: :member
  defp get_user_role(%{role: role}) when is_atom(role), do: role
  defp get_user_role(%{role: role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(_), do: :member

  defp format_role(:platform_admin), do: "Platform Admin"
  defp format_role(:gym_operator), do: "Gym Operator"
  defp format_role(:member), do: "Member"
  defp format_role(_), do: "Member"
end
