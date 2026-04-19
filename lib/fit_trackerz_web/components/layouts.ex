defmodule FitTrackerzWeb.Layouts do
  @moduledoc """
  Application layouts — authenticated sidebar layout and public layout.
  """
  use FitTrackerzWeb, :html

  embed_templates "layouts/*"

  # ────────────────────────────────────────────────────────
  # App Layout
  # ────────────────────────────────────────────────────────

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil, doc: "the current authenticated user"

  attr :unread_notification_count, :integer, default: 0

  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:user_role, get_user_role(assigns[:current_user]))
      |> assign(:nav_items, nav_items_for_role(get_user_role(assigns[:current_user])))

    ~H"""
    <%= if @current_user do %>
      <div class="drawer lg:drawer-open" id="app-drawer">
        <input id="sidebar-toggle" type="checkbox" class="drawer-toggle" />

        <%!-- Main Content Area --%>
        <div class="drawer-content flex flex-col min-h-screen bg-base-100">
          <%!-- Top Navbar --%>
          <header class="navbar bg-base-100 border-b border-base-300/50 px-4 lg:px-6 sticky top-0 z-30">
            <div class="flex-none lg:hidden">
              <label for="sidebar-toggle" class="btn btn-ghost btn-sm btn-square" aria-label="Open menu">
                <.icon name="hero-bars-3" class="size-5" />
              </label>
            </div>
            <div class="flex-1 lg:flex-none lg:hidden">
              <.brand_logo class="h-10 w-auto" />
            </div>
            <div class="flex-1 hidden lg:flex items-center">
              <button
                class="flex items-center gap-2 px-3 py-1.5 text-sm text-base-content/40 bg-base-200/50 rounded-lg hover:bg-base-200 transition-colors cursor-pointer"
                phx-click={JS.show(to: "#command-palette")}
              >
                <.icon name="hero-magnifying-glass" class="size-4" />
                <span class="hidden sm:inline">Search...</span>
                <kbd class="kbd kbd-xs">Ctrl+K</kbd>
              </button>
            </div>
            <div class="flex-none flex items-center gap-3">
              <.notification_bell current_user={@current_user} count={@unread_notification_count} />
              <.theme_toggle />
              <.user_menu current_user={@current_user} user_role={@user_role} />
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
              <a href="/dashboard">
                <.brand_logo class="h-10 w-auto" />
              </a>
              <p class="text-xs text-base-content/40 mt-1">{format_role(@user_role)} Portal</p>
            </div>

            <%!-- Navigation --%>
            <nav class="flex-1 p-3 space-y-1 overflow-y-auto">
              <.nav_group
                :for={group <- @nav_items}
                label={group.label}
                items={group.items}
              />
            </nav>

            <%!-- Sidebar Footer --%>
            <div class="p-4 border-t border-base-300/50">
              <div class="flex items-center gap-3 px-3 py-2">
                <.avatar name={@current_user.name || "User"} size="sm" />
                <div class="min-w-0">
                  <p class="text-sm font-semibold truncate">{@current_user.name}</p>
                  <p class="text-xs text-base-content/50 truncate">{@current_user.email}</p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>

      <%!-- Command Palette --%>
      <.command_palette
        id="command-palette"
        items={Enum.flat_map(@nav_items, fn group ->
          Enum.map(group.items, fn item -> %{label: item.label, path: item.href, icon: item.icon} end)
        end)}
      />
    <% else %>
      <%!-- Public layout --%>
      <.public_navbar />

      <main class="pt-24 px-4 pb-10 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-5xl">
          {render_slot(@inner_block)}
        </div>
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  # ────────────────────────────────────────────────────────
  # Nav Group
  # ────────────────────────────────────────────────────────

  attr :label, :string, required: true
  attr :items, :list, required: true

  defp nav_group(assigns) do
    ~H"""
    <div class="mb-2">
      <p class="px-3 py-1.5 text-xs font-semibold text-base-content/40 uppercase tracking-wider">
        {@label}
      </p>
      <.nav_link :for={item <- @items} href={item.href} icon={item.icon} label={item.label} />
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Nav Link (with active state)
  # ────────────────────────────────────────────────────────

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-medium transition-colors text-base-content/70 hover:text-base-content hover:bg-base-300/50"
    >
      <.icon name={@icon} class="size-5 shrink-0" />
      <span>{@label}</span>
    </a>
    """
  end

  # ────────────────────────────────────────────────────────
  # User Menu Dropdown
  # ────────────────────────────────────────────────────────

  attr :current_user, :map, required: true
  attr :user_role, :atom, required: true

  defp user_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2">
        <.avatar name={@current_user.name || "User"} size="sm" />
        <span class="hidden sm:inline text-sm font-medium">{@current_user.name}</span>
        <.icon name="hero-chevron-down-mini" class="size-3 opacity-50" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-xl z-50 w-52 p-1.5 shadow-lg border border-base-300/50"
      >
        <li class="menu-title text-xs px-2 py-1">
          {format_role(@user_role)}
        </li>
        <li>
          <a href="/sign-out" class="text-error rounded-lg">
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign Out
          </a>
        </li>
      </ul>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Sidebar Nav (kept for backwards compatibility)
  # ────────────────────────────────────────────────────────

  @doc """
  Renders role-specific sidebar navigation. Delegates to nav_items_for_role.
  Kept for any pages that still call <.sidebar_nav role={role} /> directly.
  """
  attr :role, :atom, required: true

  def sidebar_nav(assigns) do
    assigns = assign(assigns, :nav_items, nav_items_for_role(assigns.role))

    ~H"""
    <.nav_group
      :for={group <- @nav_items}
      label={group.label}
      items={group.items}
    />
    """
  end

  # ────────────────────────────────────────────────────────
  # Flash Group
  # ────────────────────────────────────────────────────────

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

  # ────────────────────────────────────────────────────────
  # Theme Toggle
  # ────────────────────────────────────────────────────────

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

  # ────────────────────────────────────────────────────────
  # Back Button
  # ────────────────────────────────────────────────────────

  def back_button(assigns) do
    ~H"""
    <button onclick="history.back()" class="btn btn-ghost btn-sm btn-circle" aria-label="Go back">
      <.icon name="hero-arrow-left" class="size-5" />
    </button>
    """
  end

  # ────────────────────────────────────────────────────────
  # Notification Bell
  # ────────────────────────────────────────────────────────

  attr :current_user, :map, required: true
  attr :count, :integer, default: 0

  def notification_bell(assigns) do
    ~H"""
    <a
      href={notification_path(@current_user)}
      class="btn btn-ghost btn-sm btn-circle relative"
      aria-label="Notifications"
      id="notification-bell"
    >
      <.icon name="hero-bell" class="size-5" />
      <span
        :if={@count > 0}
        id="notification-badge"
        class="badge badge-xs badge-error absolute -top-0.5 -right-0.5"
      >
        {if @count > 9, do: "9+", else: @count}
      </span>
    </a>
    """
  end

  # ────────────────────────────────────────────────────────
  # Navigation Items per Role
  # ────────────────────────────────────────────────────────

  defp nav_items_for_role(:platform_admin) do
    [
      %{label: "Overview", items: [
        %{href: "/admin/dashboard", icon: "hero-squares-2x2-solid", label: "Dashboard"}
      ]},
      %{label: "Management", items: [
        %{href: "/admin/users", icon: "hero-user-group-solid", label: "Users"},
        %{href: "/admin/gyms", icon: "hero-building-office-2-solid", label: "Gyms"}
      ]},
      %{label: "Analytics", items: [
        %{href: "/admin/dashboards", icon: "hero-chart-bar-square-solid", label: "Dashboards"},
        %{href: "/admin/reports", icon: "hero-document-chart-bar-solid", label: "Reports"}
      ]}
    ]
  end

  defp nav_items_for_role(:gym_operator) do
    [
      %{label: "Overview", items: [
        %{href: "/gym/dashboard", icon: "hero-squares-2x2-solid", label: "Dashboard"}
      ]},
      %{label: "Gym Management", items: [
        %{href: "/gym/setup", icon: "hero-building-office-solid", label: "My Gym"},
        %{href: "/gym/members", icon: "hero-user-group-solid", label: "Members"},
        %{href: "/gym/trainers", icon: "hero-academic-cap-solid", label: "Trainers"}
      ]},
      %{label: "Operations", items: [
        %{href: "/gym/classes", icon: "hero-calendar-days-solid", label: "Classes"},
        %{href: "/gym/plans", icon: "hero-credit-card-solid", label: "Plans & Billing"},
        %{href: "/gym/invitations", icon: "hero-envelope-solid", label: "Invitations"},
        %{href: "/gym/attendance", icon: "hero-clipboard-document-check-solid", label: "Attendance"},
        %{href: "/gym/contests", icon: "hero-trophy-solid", label: "Contests"}
      ]},
      %{label: "Communication", items: [
        %{href: "/gym/notifications", icon: "hero-bell-solid", label: "Notifications"},
        %{href: "/gym/messages", icon: "hero-chat-bubble-left-right-solid", label: "Messages"}
      ]},
      %{label: "Analytics", items: [
        %{href: "/gym/dashboards", icon: "hero-chart-bar-square-solid", label: "Dashboards"},
        %{href: "/gym/reports", icon: "hero-document-chart-bar-solid", label: "Reports"}
      ]}
    ]
  end

  defp nav_items_for_role(:trainer) do
    [
      %{label: "Overview", items: [
        %{href: "/trainer/dashboard", icon: "hero-squares-2x2-solid", label: "Dashboard"},
        %{href: "/trainer/gyms", icon: "hero-building-office-2-solid", label: "My Gyms"}
      ]},
      %{label: "Clients", items: [
        %{href: "/trainer/clients", icon: "hero-user-group-solid", label: "My Clients"},
        %{href: "/trainer/attendance", icon: "hero-clipboard-document-check-solid", label: "Attendance"}
      ]},
      %{label: "Programs", items: [
        %{href: "/trainer/workouts", icon: "hero-fire-solid", label: "Workout Plans"},
        %{href: "/trainer/diets", icon: "hero-heart-solid", label: "Diet Plans"},
        %{href: "/trainer/templates", icon: "hero-document-duplicate-solid", label: "Templates"}
      ]},
      %{label: "Communication", items: [
        %{href: "/trainer/messages", icon: "hero-chat-bubble-left-right-solid", label: "Messages"},
        %{href: "/trainer/reports", icon: "hero-document-chart-bar-solid", label: "Reports"}
      ]},
      %{label: "Schedule", items: [
        %{href: "/trainer/classes", icon: "hero-calendar-days-solid", label: "My Classes"}
      ]}
    ]
  end

  defp nav_items_for_role(_member) do
    [
      %{label: "Overview", items: [
        %{href: "/member/dashboard", icon: "hero-squares-2x2-solid", label: "Dashboard"},
        %{href: "/member/gym", icon: "hero-building-office-2-solid", label: "My Gyms"},
        %{href: "/member/trainer", icon: "hero-academic-cap-solid", label: "My Trainer"}
      ]},
      %{label: "Fitness", items: [
        %{href: "/member/workout", icon: "hero-fire-solid", label: "My Workout"},
        %{href: "/member/diet", icon: "hero-heart-solid", label: "My Diet Plan"},
        %{href: "/member/attendance", icon: "hero-clipboard-document-check-solid", label: "Attendance"}
      ]},
      %{label: "Classes", items: [
        %{href: "/member/classes", icon: "hero-calendar-days-solid", label: "Browse Classes"},
        %{href: "/member/bookings", icon: "hero-ticket-solid", label: "My Bookings"}
      ]},
      %{label: "Account", items: [
        %{href: "/member/subscription", icon: "hero-credit-card-solid", label: "Subscription"},
        %{href: "/member/notifications", icon: "hero-bell-solid", label: "Notifications"},
        %{href: "/member/messages", icon: "hero-chat-bubble-left-right-solid", label: "Messages"}
      ]},
      %{label: "Health", items: [
        %{href: "/member/health", icon: "hero-chart-bar-solid", label: "Health Metrics"},
        %{href: "/member/food", icon: "hero-cake-solid", label: "Food Log"},
        %{href: "/member/progress", icon: "hero-arrow-trending-up-solid", label: "Progress"}
      ]}
    ]
  end

  # ────────────────────────────────────────────────────────
  # Public Navbar (shared across all public pages)
  # ────────────────────────────────────────────────────────

  def public_navbar(assigns) do
    ~H"""
    <nav class="navbar bg-base-100/90 backdrop-blur-lg fixed top-0 left-0 right-0 z-50 border-b border-base-300/50 px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/">
          <.brand_logo class="h-10 w-auto" />
        </a>
      </div>

      <%!-- Desktop Menu --%>
      <div class="flex-none hidden lg:flex items-center gap-3">
        <%!-- Solutions Dropdown --%>
        <div class="dropdown dropdown-hover">
          <label tabindex="0" class="btn btn-ghost btn-sm font-semibold">
            Solutions
            <.icon name="hero-chevron-down" class="size-4 ml-1" />
          </label>
          <ul
            tabindex="0"
            class="dropdown-content menu p-2 shadow-lg bg-base-200 rounded-box w-56 mt-1 border border-base-300/50"
          >
            <li>
              <a href="/solutions/members" class="flex items-center gap-3 py-3">
                <.icon name="hero-user-solid" class="size-5 text-accent" />
                <div>
                  <div class="font-semibold">For Members</div>
                  <div class="text-xs text-base-content/60">Find your perfect gym</div>
                </div>
              </a>
            </li>
            <li>
              <a href="/solutions/trainers" class="flex items-center gap-3 py-3">
                <.icon name="hero-academic-cap-solid" class="size-5 text-secondary" />
                <div>
                  <div class="font-semibold">For Trainers</div>
                  <div class="text-xs text-base-content/60">Grow your training business</div>
                </div>
              </a>
            </li>
            <li>
              <a href="/solutions/operators" class="flex items-center gap-3 py-3">
                <.icon name="hero-building-office-2-solid" class="size-5 text-primary" />
                <div>
                  <div class="font-semibold">For Gym Operators</div>
                  <div class="text-xs text-base-content/60">Manage your gym efficiently</div>
                </div>
              </a>
            </li>
          </ul>
        </div>

        <a href="/about" class="btn btn-ghost btn-sm font-semibold">About Us</a>
        <a href="/explore" class="btn btn-ghost btn-sm font-semibold">Explore Gyms</a>
        <a href="/explore/contests" class="btn btn-ghost btn-sm font-semibold">Contests</a>
        <.theme_toggle />
        <a href="/sign-in" class="btn btn-ghost btn-sm font-semibold">Sign In</a>
        <a href="/register" class="btn btn-primary btn-sm font-bold">Get Started</a>
      </div>

      <%!-- Mobile Menu Button --%>
      <div class="flex-none lg:hidden">
        <button
          id="mobile-menu-btn"
          class="btn btn-ghost btn-square btn-sm"
          aria-label="Open menu"
        >
          <.icon name="hero-bars-3" class="size-6" />
        </button>
      </div>
    </nav>

    <%!-- Mobile Menu Overlay --%>
    <div
      id="mobile-menu"
      class="fixed inset-0 z-40 bg-base-100 transform translate-x-full transition-transform duration-300 lg:hidden"
    >
      <div class="flex flex-col h-full">
        <%!-- Mobile Menu Header --%>
        <div class="flex items-center justify-between p-4 border-b border-base-300">
          <a href="/">
            <.brand_logo class="h-10 w-auto" />
          </a>
          <button
            id="mobile-menu-close"
            class="btn btn-ghost btn-square btn-sm"
            aria-label="Close menu"
          >
            <.icon name="hero-x-mark" class="size-6" />
          </button>
        </div>

        <%!-- Mobile Menu Links --%>
        <div class="flex-1 overflow-y-auto p-4">
          <div class="space-y-2">
            <%!-- Solutions Expandable --%>
            <details class="collapse collapse-arrow bg-base-200 rounded-box">
              <summary class="collapse-title font-semibold">Solutions</summary>
              <div class="collapse-content space-y-2">
                <a
                  href="/solutions/members"
                  class="flex items-center gap-3 p-3 hover:bg-base-300 rounded-lg"
                >
                  <.icon name="hero-user-solid" class="size-5 text-accent" />
                  <div>
                    <div class="font-semibold text-sm">For Members</div>
                    <div class="text-xs text-base-content/60">Find your perfect gym</div>
                  </div>
                </a>
                <a
                  href="/solutions/trainers"
                  class="flex items-center gap-3 p-3 hover:bg-base-300 rounded-lg"
                >
                  <.icon name="hero-academic-cap-solid" class="size-5 text-secondary" />
                  <div>
                    <div class="font-semibold text-sm">For Trainers</div>
                    <div class="text-xs text-base-content/60">Grow your training business</div>
                  </div>
                </a>
                <a
                  href="/solutions/operators"
                  class="flex items-center gap-3 p-3 hover:bg-base-300 rounded-lg"
                >
                  <.icon name="hero-building-office-2-solid" class="size-5 text-primary" />
                  <div>
                    <div class="font-semibold text-sm">For Gym Operators</div>
                    <div class="text-xs text-base-content/60">Manage your gym efficiently</div>
                  </div>
                </a>
              </div>
            </details>

            <a href="/about" class="btn btn-ghost btn-block justify-start font-semibold">
              About Us
            </a>
            <a href="/explore" class="btn btn-ghost btn-block justify-start font-semibold">
              Explore Gyms
            </a>
            <a href="/explore/contests" class="btn btn-ghost btn-block justify-start font-semibold">
              Contests
            </a>
            <a href="/sign-in" class="btn btn-ghost btn-block justify-start font-semibold">
              Sign In
            </a>
            <a href="/register" class="btn btn-primary btn-block font-bold">Get Started</a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Helpers
  # ────────────────────────────────────────────────────────

  defp notification_path(user) do
    case get_user_role(user) do
      :gym_operator -> "/gym/notifications"
      :trainer -> "/trainer/notifications"
      :platform_admin -> "/admin/notifications"
      _ -> "/member/notifications"
    end
  end

  defp get_user_role(nil), do: :member
  defp get_user_role(%{role: role}) when is_atom(role), do: role
  defp get_user_role(%{role: role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(%{"role" => role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_user_role(%{"role" => role}) when is_atom(role), do: role
  defp get_user_role(_), do: :member

  defp format_role(:platform_admin), do: "Platform Admin"
  defp format_role(:gym_operator), do: "Gym Operator"
  defp format_role(:trainer), do: "Trainer"
  defp format_role(:member), do: "Member"
  defp format_role(_), do: "Member"
end
