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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Platform Admin" subtitle={"Welcome back, #{@current_user.name}. Here's your platform overview."}>
        <:actions>
          <.button variant="ghost" size="sm" icon="hero-chart-bar" navigate="/admin/dashboards">Dashboards</.button>
          <.button variant="ghost" size="sm" icon="hero-document-text" navigate="/admin/reports">Reports</.button>
        </:actions>
      </.page_header>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
        <.stat_card label="Total Users" value={@user_count} icon="hero-user-group-solid" color="primary" />
        <.stat_card label="Verified Gyms" value={@gym_count} icon="hero-building-office-2-solid" color="secondary" />
        <.stat_card label="Pending Gyms" value={@pending_count} icon="hero-clock-solid" color="warning" />
        <.stat_card label="Subscriptions" value={@subscription_count} icon="hero-credit-card-solid" color="accent" />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Quick Actions --%>
        <.card title="Quick Actions">
          <:header_actions>
            <.icon name="hero-bolt-solid" class="size-5 text-primary" />
          </:header_actions>
          <div class="grid grid-cols-2 gap-3">
            <.button variant="ghost" size="sm" icon="hero-user-group" navigate="/admin/users">Manage Users</.button>
            <.button variant="ghost" size="sm" icon="hero-building-office-2" navigate="/admin/gyms">Manage Gyms</.button>
            <.button variant="ghost" size="sm" icon="hero-chart-bar" navigate="/admin/dashboards">Dashboards</.button>
            <.button variant="ghost" size="sm" icon="hero-document-text" navigate="/admin/reports">Reports</.button>
          </div>
        </.card>

        <%!-- Pending Verifications --%>
        <.card title="Pending Verifications">
          <:header_actions>
            <.badge :if={@pending_count > 0} variant="warning">{@pending_count}</.badge>
          </:header_actions>
          <%= if @pending_gyms == [] do %>
            <.empty_state
              icon="hero-check-circle"
              title="All clear"
              subtitle="All gyms are verified. No pending verifications."
            />
          <% else %>
            <div class="space-y-2">
              <div
                :for={gym <- @pending_gyms}
                class="flex items-center justify-between p-3 rounded-xl bg-base-200/50 border border-base-300/30"
                id={"pending-gym-#{gym.id}"}
              >
                <div class="flex items-center gap-3 min-w-0">
                  <.avatar name={gym.name} size="sm" />
                  <div class="min-w-0">
                    <p class="text-sm font-semibold truncate">{gym.name}</p>
                    <p class="text-xs text-base-content/50">by {gym.owner.name}</p>
                  </div>
                </div>
                <.button variant="primary" size="sm" icon="hero-shield-check" phx-click="verify_gym" phx-value-id={gym.id}>
                  Verify
                </.button>
              </div>
            </div>
          <% end %>
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
