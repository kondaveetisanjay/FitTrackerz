defmodule FitTrackerzWeb.Admin.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    user_count =
      case FitTrackerz.Accounts.list_users(actor: actor) do
        {:ok, users} -> length(users)
        _ -> 0
      end

    gym_count =
      case FitTrackerz.Gym.list_verified_gyms(actor: actor) do
        {:ok, gyms} -> length(gyms)
        _ -> 0
      end

    pending_gyms =
      case FitTrackerz.Gym.list_pending_gyms(actor: actor) do
        {:ok, gyms} -> gyms
        _ -> []
      end

    pending_count = length(pending_gyms)

    subscription_count =
      case FitTrackerz.Billing.list_subscriptions(actor: actor) do
        {:ok, subs} -> length(subs)
        _ -> 0
      end

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       user_count: user_count,
       gym_count: gym_count,
       pending_count: pending_count,
       subscription_count: subscription_count,
       pending_gyms: pending_gyms
     )}
  end

  @impl true
  def handle_event("verify_gym", %{"id" => gym_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_gym(gym_id, actor: actor) do
      {:ok, gym} ->
        case FitTrackerz.Gym.update_gym(gym, %{status: :verified}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Gym verified successfully!")
             |> push_navigate(to: ~p"/admin/dashboard")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to verify gym.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gym not found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="relative rounded-2xl overflow-hidden gradient-mesh bg-base-200/50 border border-base-300/30">
          <div class="relative p-6 sm:p-8">
            <p class="text-sm text-base-content/40 font-medium tracking-wide">Platform Admin</p>
            <h1 class="text-2xl sm:text-3xl font-brand mt-1.5">
              Welcome, {@current_user.name}
            </h1>
            <p class="text-base-content/50 mt-1.5 text-sm">
              Here's your platform overview at a glance.
            </p>
          </div>
        </div>

        <%!-- Stats Grid --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <.stat_card
            label="Total Users"
            value={@user_count}
            icon="hero-user-group-solid"
            color="primary"
            subtitle="View all users"
            href="/admin/users"
            id="stat-users"
          />
          <.stat_card
            label="Verified Gyms"
            value={@gym_count}
            icon="hero-building-office-2-solid"
            color="secondary"
            subtitle="Manage gyms"
            href="/admin/gyms"
            id="stat-gyms"
          />
          <.stat_card
            label="Subscriptions"
            value={@subscription_count}
            icon="hero-credit-card-solid"
            color="warning"
            subtitle="Active plans"
            id="stat-subscriptions"
          />
        </div>

        <%!-- Quick Actions & Pending --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="premium-card" id="quick-actions">
            <div class="p-5">
              <.section_header icon="hero-bolt-solid" icon_color="primary" title="Quick Actions" />

              <div class="grid grid-cols-2 gap-3 mt-4">
                <.link
                  navigate="/admin/users"
                  class="flex items-center gap-3 p-3.5 rounded-xl bg-base-300/20 hover:bg-base-300/30 transition-colors group"
                >
                  <div class="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center group-hover:scale-105 transition-transform">
                    <.icon name="hero-user-group" class="size-4 text-primary" />
                  </div>
                  <span class="text-sm font-semibold">Manage Users</span>
                </.link>
                <.link
                  navigate="/admin/gyms"
                  class="flex items-center gap-3 p-3.5 rounded-xl bg-base-300/20 hover:bg-base-300/30 transition-colors group"
                >
                  <div class="w-9 h-9 rounded-lg bg-secondary/10 flex items-center justify-center group-hover:scale-105 transition-transform">
                    <.icon name="hero-building-office-2" class="size-4 text-secondary" />
                  </div>
                  <span class="text-sm font-semibold">Manage Gyms</span>
                </.link>
              </div>
            </div>
          </div>

          <div class="premium-card" id="pending-verifications">
            <div class="p-5">
              <.section_header icon="hero-clock-solid" icon_color="warning" title="Pending Verifications">
                <:actions>
                  <%= if @pending_count > 0 do %>
                    <span class="badge badge-warning badge-sm">{@pending_count}</span>
                  <% end %>
                </:actions>
              </.section_header>

              <div class="mt-4 space-y-3">
                <%= if @pending_gyms == [] do %>
                  <div class="flex items-center gap-3 p-3.5 rounded-xl bg-success/5 border border-success/10">
                    <div class="w-8 h-8 rounded-lg bg-success/10 flex items-center justify-center">
                      <.icon name="hero-check-circle" class="size-4 text-success" />
                    </div>
                    <p class="text-sm text-base-content/50">
                      All gyms are verified. No pending verifications.
                    </p>
                  </div>
                <% else %>
                  <%= for gym <- @pending_gyms do %>
                    <div class="flex items-center justify-between p-3.5 rounded-xl bg-base-300/20 hover:bg-base-300/30 transition-colors">
                      <div class="flex items-center gap-3">
                        <div class="w-9 h-9 rounded-lg bg-gradient-to-br from-warning/15 to-warning/5 flex items-center justify-center">
                          <.icon name="hero-building-office-2" class="size-4 text-warning" />
                        </div>
                        <div>
                          <p class="text-sm font-bold">{gym.name}</p>
                          <p class="text-xs text-base-content/35 mt-0.5">by {gym.owner.name}</p>
                        </div>
                      </div>
                      <button
                        phx-click="verify_gym"
                        phx-value-id={gym.id}
                        class="btn btn-success btn-xs font-semibold shadow-sm"
                      >
                        Verify
                      </button>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

