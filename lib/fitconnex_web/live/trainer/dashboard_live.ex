defmodule FitconnexWeb.Trainer.DashboardLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    uid = user.id

    gym_trainers =
      Fitconnex.Gym.GymTrainer
      |> Ash.Query.filter(user_id == ^uid)
      |> Ash.Query.filter(is_active == true)
      |> Ash.Query.load([:gym])
      |> Ash.read!()

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(
         page_title: "Trainer Dashboard",
         no_gym: true,
         client_count: 0,
         class_count: 0,
         workout_count: 0,
         diet_count: 0,
         clients: [],
         upcoming_classes: []
       )}
    else
      clients =
        Fitconnex.Gym.GymMember
        |> Ash.Query.filter(assigned_trainer_id == ^uid)
        |> Ash.Query.load([:user, :gym])
        |> Ash.read!()

      classes =
        Fitconnex.Scheduling.ScheduledClass
        |> Ash.Query.filter(trainer_id == ^uid)
        |> Ash.Query.filter(status == :scheduled)
        |> Ash.Query.load([:class_definition, :branch])
        |> Ash.read!()

      workout_count =
        Fitconnex.Training.WorkoutPlan
        |> Ash.Query.filter(trainer_id == ^uid)
        |> Ash.count!()

      diet_count =
        Fitconnex.Training.DietPlan
        |> Ash.Query.filter(trainer_id == ^uid)
        |> Ash.count!()

      {:ok,
       socket
       |> assign(
         page_title: "Trainer Dashboard",
         no_gym: false,
         client_count: length(clients),
         class_count: length(classes),
         workout_count: workout_count,
         diet_count: diet_count,
         clients: Enum.take(clients, 5),
         upcoming_classes: Enum.take(classes, 5)
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Trainer Dashboard</h1>

            <p class="text-base-content/50 mt-1">
              Manage your clients, classes, and training programs.
            </p>
          </div>

          <div class="flex gap-2">
            <.link navigate="/trainer/workouts" class="btn btn-primary btn-sm gap-2 font-semibold">
              <.icon name="hero-plus-mini" class="size-4" /> New Workout Plan
            </.link>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="min-h-[40vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-warning/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-academic-cap-solid" class="size-10 text-warning" />
              </div>

              <h2 class="text-xl font-black tracking-tight">No Gym Association</h2>

              <p class="text-base-content/50 mt-3">
                You haven't been added to any gym yet. Ask a gym operator to invite you as a trainer.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate="/trainer/clients"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-clients"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      My Clients
                    </p>

                    <p class="text-3xl font-black mt-1">{@client_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Assigned members</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/classes"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-upcoming-classes"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Upcoming Classes
                    </p>

                    <p class="text-3xl font-black mt-1">{@class_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-calendar-days-solid" class="size-6 text-info" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Scheduled</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/workouts"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-workout-plans"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Workout Plans
                    </p>

                    <p class="text-3xl font-black mt-1">{@workout_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                    <.icon name="hero-fire-solid" class="size-6 text-accent" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Created plans</p>
              </div>
            </.link>
            <.link
              navigate="/trainer/diets"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-diet-plans"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Diet Plans
                    </p>

                    <p class="text-3xl font-black mt-1">{@diet_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-heart-solid" class="size-6 text-success" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Active plans</p>
              </div>
            </.link>
          </div>
          <%!-- Main Content Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Quick Actions --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="quick-actions">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-bolt-solid" class="size-5 text-primary" /> Quick Actions
                </h2>

                <div class="space-y-2 mt-4">
                  <.link
                    navigate="/trainer/workouts"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-fire" class="size-4 text-accent" /> New Workout
                  </.link>
                  <.link
                    navigate="/trainer/diets"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-heart" class="size-4 text-success" /> New Diet Plan
                  </.link>
                  <.link
                    navigate="/trainer/templates"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-document-duplicate" class="size-4 text-info" /> Templates
                  </.link>
                  <.link
                    navigate="/trainer/attendance"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-clipboard-document-check" class="size-4 text-warning" />
                    Mark Attendance
                  </.link>
                </div>
              </div>
            </div>
            <%!-- Upcoming Classes --%>
            <div
              class="lg:col-span-2 card bg-base-200/50 border border-base-300/50"
              id="upcoming-classes-card"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-calendar-solid" class="size-5 text-info" /> Upcoming Classes
                  </h2>

                  <.link navigate="/trainer/classes" class="btn btn-ghost btn-xs gap-1">
                    View All <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @upcoming_classes == [] do %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <.icon name="hero-calendar" class="size-5 text-base-content/30" />
                      <p class="text-sm text-base-content/50">No upcoming classes scheduled.</p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Class</th>

                            <th>Branch</th>

                            <th>Scheduled</th>

                            <th>Duration</th>
                          </tr>
                        </thead>

                        <tbody>
                          <%= for sc <- @upcoming_classes do %>
                            <tr>
                              <td class="font-medium">{sc.class_definition.name}</td>

                              <td class="text-base-content/60">
                                {if sc.branch, do: sc.branch.city, else: "N/A"}
                              </td>

                              <td class="text-base-content/60">
                                {Calendar.strftime(sc.scheduled_at, "%b %d, %H:%M")}
                              </td>

                              <td>{sc.duration_minutes} min</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <%!-- Clients List --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="client-list">
            <div class="card-body p-5">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-user-group-solid" class="size-5 text-primary" /> My Clients
                </h2>

                <.link navigate="/trainer/clients" class="btn btn-ghost btn-xs gap-1">
                  View All <.icon name="hero-arrow-right-mini" class="size-3" />
                </.link>
              </div>

              <div class="mt-4">
                <%= if @clients == [] do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <.icon name="hero-user-group" class="size-5 text-base-content/30" />
                    <p class="text-sm text-base-content/50">
                      No clients assigned yet. Members will appear here once assigned by the gym operator.
                    </p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr class="text-base-content/40">
                          <th>Name</th>

                          <th>Email</th>

                          <th>Gym</th>

                          <th>Status</th>
                        </tr>
                      </thead>

                      <tbody>
                        <%= for client <- @clients do %>
                          <tr>
                            <td class="font-medium">{client.user.name}</td>

                            <td class="text-base-content/60">{client.user.email}</td>

                            <td class="text-base-content/60">{client.gym.name}</td>

                            <td>
                              <%= if client.is_active do %>
                                <span class="badge badge-success badge-sm">Active</span>
                              <% else %>
                                <span class="badge badge-ghost badge-sm">Inactive</span>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
