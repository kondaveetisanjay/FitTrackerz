defmodule FitconnexWeb.Admin.DashboardLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    user_count =
      case Fitconnex.Accounts.list_users(actor: actor) do
        {:ok, users} -> length(users)
        _ -> 0
      end

    gym_count =
      case Fitconnex.Gym.list_verified_gyms(actor: actor) do
        {:ok, gyms} -> length(gyms)
        _ -> 0
      end

    pending_gyms =
      case Fitconnex.Gym.list_pending_gyms(actor: actor) do
        {:ok, gyms} -> gyms
        _ -> []
      end

    pending_count = length(pending_gyms)

    trainer_count =
      case Fitconnex.Accounts.list_users(actor: actor) do
        {:ok, users} -> Enum.count(users, fn u -> u.role == :trainer end)
        _ -> 0
      end

    subscription_count =
      case Fitconnex.Billing.list_subscriptions(actor: actor) do
        {:ok, subs} -> length(subs)
        _ -> 0
      end

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       user_count: user_count,
       gym_count: gym_count,
       pending_count: pending_count,
       trainer_count: trainer_count,
       subscription_count: subscription_count,
       pending_gyms: pending_gyms
     )}
  end

  @impl true
  def handle_event("verify_gym", %{"id" => gym_id}, socket) do
    actor = socket.assigns.current_user

    case Fitconnex.Gym.get_gym(gym_id, actor: actor) do
      {:ok, gym} ->
        case Fitconnex.Gym.update_gym(gym, %{status: :verified}, actor: actor) do
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
        <div>
          <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Platform Admin</h1>

          <p class="text-base-content/50 mt-1">
            Welcome back, {@current_user.name}. Here's your platform overview.
          </p>
        </div>
        <%!-- Stats Grid --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="card bg-base-200/50 border border-base-300/50" id="stat-users">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Total Users
                  </p>

                  <p class="text-3xl font-black mt-1">{@user_count}</p>
                </div>

                <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                  <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                </div>
              </div>

              <.link
                navigate="/admin/users"
                class="text-xs text-primary mt-2 flex items-center gap-1 hover:underline"
              >
                View all users <.icon name="hero-arrow-right-mini" class="size-3" />
              </.link>
            </div>
          </div>

          <div class="card bg-base-200/50 border border-base-300/50" id="stat-gyms">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Verified Gyms
                  </p>

                  <p class="text-3xl font-black mt-1">{@gym_count}</p>
                </div>

                <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center">
                  <.icon name="hero-building-office-2-solid" class="size-6 text-secondary" />
                </div>
              </div>

              <.link
                navigate="/admin/gyms"
                class="text-xs text-secondary mt-2 flex items-center gap-1 hover:underline"
              >
                Manage gyms <.icon name="hero-arrow-right-mini" class="size-3" />
              </.link>
            </div>
          </div>

          <div class="card bg-base-200/50 border border-base-300/50" id="stat-trainers">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Trainers
                  </p>

                  <p class="text-3xl font-black mt-1">{@trainer_count}</p>
                </div>

                <div class="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                  <.icon name="hero-academic-cap-solid" class="size-6 text-accent" />
                </div>
              </div>

              <p class="text-xs text-base-content/40 mt-2">Across all gyms</p>
            </div>
          </div>

          <div class="card bg-base-200/50 border border-base-300/50" id="stat-subscriptions">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Subscriptions
                  </p>

                  <p class="text-3xl font-black mt-1">{@subscription_count}</p>
                </div>

                <div class="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center">
                  <.icon name="hero-credit-card-solid" class="size-6 text-warning" />
                </div>
              </div>

              <p class="text-xs text-base-content/40 mt-2">Active plans</p>
            </div>
          </div>
        </div>
        <%!-- Quick Actions & Pending --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="card bg-base-200/50 border border-base-300/50" id="quick-actions">
            <div class="card-body p-5">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-bolt-solid" class="size-5 text-primary" /> Quick Actions
              </h2>

              <div class="grid grid-cols-2 gap-3 mt-4">
                <.link
                  navigate="/admin/users"
                  class="btn btn-ghost bg-base-300/30 btn-sm justify-start gap-2 font-medium"
                >
                  <.icon name="hero-user-group" class="size-4 text-primary" /> Manage Users
                </.link>
                <.link
                  navigate="/admin/gyms"
                  class="btn btn-ghost bg-base-300/30 btn-sm justify-start gap-2 font-medium"
                >
                  <.icon name="hero-building-office-2" class="size-4 text-secondary" /> Manage Gyms
                </.link>
              </div>
            </div>
          </div>

          <div class="card bg-base-200/50 border border-base-300/50" id="pending-verifications">
            <div class="card-body p-5">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-clock-solid" class="size-5 text-warning" /> Pending Verifications
                <%= if @pending_count > 0 do %>
                  <span class="badge badge-warning badge-sm">{@pending_count}</span>
                <% end %>
              </h2>

              <div class="mt-4 space-y-3">
                <%= if @pending_gyms == [] do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <.icon name="hero-check-circle" class="size-5 text-success" />
                    <p class="text-sm text-base-content/50">
                      All gyms are verified. No pending verifications.
                    </p>
                  </div>
                <% else %>
                  <%= for gym <- @pending_gyms do %>
                    <div class="flex items-center justify-between p-3 rounded-lg bg-base-300/30">
                      <div class="flex items-center gap-3">
                        <div class="w-8 h-8 rounded-lg bg-warning/10 flex items-center justify-center">
                          <.icon name="hero-building-office-2" class="size-4 text-warning" />
                        </div>

                        <div>
                          <p class="text-sm font-semibold">{gym.name}</p>

                          <p class="text-xs text-base-content/40">by {gym.owner.name}</p>
                        </div>
                      </div>

                      <button
                        phx-click="verify_gym"
                        phx-value-id={gym.id}
                        class="btn btn-success btn-xs"
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
