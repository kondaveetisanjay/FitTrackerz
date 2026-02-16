defmodule FitconnexWeb.GymOperator.DashboardLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    uid = socket.assigns.current_user.id

    gyms =
      Fitconnex.Gym.Gym
      |> Ash.Query.filter(owner_id == ^uid)
      |> Ash.Query.load([
        :branches,
        :gym_members,
        :gym_trainers,
        :member_invitations,
        :trainer_invitations
      ])
      |> Ash.read!()

    case gyms do
      [gym | _] ->
        member_count = length(gym.gym_members)
        trainer_count = length(gym.gym_trainers)

        pending_member_invites =
          Enum.count(gym.member_invitations, fn inv -> inv.status == :pending end)

        pending_trainer_invites =
          Enum.count(gym.trainer_invitations, fn inv -> inv.status == :pending end)

        scheduled_classes =
          Fitconnex.Scheduling.ScheduledClass
          |> Ash.Query.filter(status == :scheduled)
          |> Ash.Query.load([:class_definition, :branch, :trainer])
          |> Ash.read!()
          |> Enum.filter(fn sc ->
            Enum.any?(gym.branches, fn b -> b.id == sc.branch_id end)
          end)
          |> Enum.take(5)

        {:ok,
         assign(socket,
           page_title: "Gym Dashboard",
           gym: gym,
           has_gym: true,
           member_count: member_count,
           trainer_count: trainer_count,
           pending_member_invites: pending_member_invites,
           pending_trainer_invites: pending_trainer_invites,
           scheduled_classes: scheduled_classes
         )}

      [] ->
        {:ok,
         assign(socket,
           page_title: "Gym Dashboard",
           gym: nil,
           has_gym: false,
           member_count: 0,
           trainer_count: 0,
           pending_member_invites: 0,
           pending_trainer_invites: 0,
           scheduled_classes: []
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%= if @has_gym do %>
          <%!-- Page Header --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <div class="flex items-center gap-3">
                <h1 class="text-2xl sm:text-3xl font-black tracking-tight">{@gym.name}</h1>

                <span class={[
                  "badge badge-sm",
                  @gym.status == :verified && "badge-success",
                  @gym.status == :pending_verification && "badge-warning",
                  @gym.status == :suspended && "badge-error"
                ]}>
                  {Phoenix.Naming.humanize(@gym.status)}
                </span>
              </div>

              <p class="text-base-content/50 mt-1">Manage your gym, members, and trainers.</p>
            </div>

            <div class="flex gap-2">
              <.link navigate="/gym/members" class="btn btn-primary btn-sm gap-2 font-semibold">
                <.icon name="hero-user-plus-mini" class="size-4" /> Members
              </.link>
              <.link
                navigate="/gym/trainers"
                class="btn btn-ghost bg-base-200 btn-sm gap-2 font-semibold"
              >
                <.icon name="hero-academic-cap-mini" class="size-4" /> Trainers
              </.link>
            </div>
          </div>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              navigate="/gym/members"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-members"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Members
                    </p>

                    <p class="text-3xl font-black mt-1">{@member_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Active members</p>
              </div>
            </.link>
            <.link
              navigate="/gym/trainers"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-trainers"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Trainers
                    </p>

                    <p class="text-3xl font-black mt-1">{@trainer_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center">
                    <.icon name="hero-academic-cap-solid" class="size-6 text-secondary" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">On staff</p>
              </div>
            </.link>
            <.link
              navigate="/gym/invitations"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-invites"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Pending Invites
                    </p>

                    <p class="text-3xl font-black mt-1">
                      {@pending_member_invites + @pending_trainer_invites}
                    </p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center">
                    <.icon name="hero-envelope-solid" class="size-6 text-warning" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Awaiting response</p>
              </div>
            </.link>
          </div>
          <%!-- Quick Actions & Upcoming --%>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="card bg-base-200/50 border border-base-300/50" id="quick-actions">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-bolt-solid" class="size-5 text-primary" /> Quick Actions
                </h2>

                <div class="space-y-2 mt-4">
                  <.link
                    navigate="/gym/members"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-user-plus" class="size-4 text-primary" /> Invite Member
                  </.link>
                  <.link
                    navigate="/gym/trainers"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-academic-cap" class="size-4 text-secondary" /> Invite Trainer
                  </.link>
                  <.link
                    navigate="/gym/classes"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-calendar-days" class="size-4 text-info" /> Schedule Class
                  </.link>
                  <.link
                    navigate="/gym/plans"
                    class="btn btn-ghost bg-base-300/30 btn-sm w-full justify-start gap-3 font-medium"
                  >
                    <.icon name="hero-credit-card" class="size-4 text-warning" /> Manage Plans
                  </.link>
                </div>
              </div>
            </div>

            <div
              class="lg:col-span-2 card bg-base-200/50 border border-base-300/50"
              id="upcoming-classes"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-calendar-solid" class="size-5 text-info" /> Upcoming Classes
                  </h2>

                  <.link navigate="/gym/classes" class="btn btn-ghost btn-xs gap-1">
                    View All <.icon name="hero-arrow-right-mini" class="size-3" />
                  </.link>
                </div>

                <div class="mt-4">
                  <%= if @scheduled_classes == [] do %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <.icon name="hero-calendar" class="size-5 text-base-content/30" />
                      <p class="text-sm text-base-content/50">
                        No upcoming classes.
                        <.link navigate="/gym/classes" class="text-primary hover:underline">
                          Schedule one
                        </.link>
                      </p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Class</th>

                            <th>Trainer</th>

                            <th>Scheduled</th>

                            <th>Duration</th>
                          </tr>
                        </thead>

                        <tbody>
                          <%= for sc <- @scheduled_classes do %>
                            <tr>
                              <td class="font-medium">{sc.class_definition.name}</td>

                              <td class="text-base-content/60">
                                {if sc.trainer, do: sc.trainer.name, else: "Unassigned"}
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
        <% else %>
          <%!-- No Gym Setup --%>
          <div class="min-h-[60vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-primary/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-building-office-2-solid" class="size-10 text-primary" />
              </div>

              <h1 class="text-2xl font-black tracking-tight">Set Up Your Gym</h1>

              <p class="text-base-content/50 mt-3">
                You haven't created a gym yet. Get started by setting up your gym profile and adding your first branch.
              </p>

              <.link navigate="/gym/setup" class="btn btn-primary btn-lg gap-2 mt-8 font-bold">
                <.icon name="hero-plus-mini" class="size-5" /> Create Your Gym
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
