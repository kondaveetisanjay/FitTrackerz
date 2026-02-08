defmodule FitconnexWeb.Member.WorkoutLive do
  use FitconnexWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    uid = user.id

    memberships =
      try do
        Fitconnex.Gym.GymMember
        |> Ash.Query.filter(user_id == ^uid)
        |> Ash.Query.filter(is_active == true)
        |> Ash.Query.load([:gym, :assigned_trainer])
        |> Ash.read!()
      rescue
        _ -> []
      end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My Workout",
           memberships: [],
           workout_plans: [],
           no_gym: true
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)

        workout_plans =
          try do
            Fitconnex.Training.WorkoutPlan
            |> Ash.Query.filter(member_id in ^mids)
            |> Ash.Query.load([:gym, :trainer])
            |> Ash.read!()
          rescue
            _ -> []
          end

        {:ok,
         assign(socket,
           page_title: "My Workout",
           memberships: memberships,
           workout_plans: workout_plans,
           no_gym: false
         )}
    end
  end

  defp format_duration(nil), do: nil

  defp format_duration(seconds) when seconds >= 60,
    do: "#{div(seconds, 60)}m #{rem(seconds, 60)}s"

  defp format_duration(seconds), do: "#{seconds}s"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Workout Plans</h1>
              <p class="text-base-content/50 mt-1">View your personalized workout programs.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <%!-- No Gym Membership --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You haven't joined any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%= if @workout_plans == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-workout-plans">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-accent/10 flex items-center justify-center mb-4">
                  <.icon name="hero-fire" class="size-8 text-accent" />
                </div>
                <h2 class="text-lg font-bold">No Workout Plans Yet</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  Your trainer will assign a workout plan tailored for you. Check back soon!
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Workout Plan Cards --%>
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div
                :for={plan <- @workout_plans}
                class="card bg-base-200/50 border border-base-300/50"
                id={"workout-plan-#{plan.id}"}
              >
                <div class="card-body p-5">
                  <%!-- Plan Header --%>
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <h2 class="text-lg font-bold flex items-center gap-2">
                        <.icon name="hero-fire-solid" class="size-5 text-accent" />
                        {plan.name}
                      </h2>
                      <div class="flex flex-wrap items-center gap-3 mt-2 text-xs text-base-content/50">
                        <%= if plan.gym do %>
                          <span class="flex items-center gap-1">
                            <.icon name="hero-building-office-2-mini" class="size-3" />
                            {plan.gym.name}
                          </span>
                        <% end %>
                        <%= if plan.trainer do %>
                          <span class="flex items-center gap-1">
                            <.icon name="hero-user-mini" class="size-3" />
                            {plan.trainer.name}
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <div class="badge badge-accent badge-outline badge-sm">
                      {length(plan.exercises || [])} exercises
                    </div>
                  </div>

                  <%!-- Exercises --%>
                  <div class="mt-4 space-y-2">
                    <div
                      :for={exercise <- Enum.sort_by(plan.exercises || [], & &1.order)}
                      class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20"
                      id={"exercise-#{plan.id}-#{exercise.order}"}
                    >
                      <div class="w-7 h-7 rounded-lg bg-accent/10 flex items-center justify-center shrink-0">
                        <span class="text-xs font-bold text-accent">{exercise.order}</span>
                      </div>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold truncate">{exercise.name}</p>
                        <div class="flex flex-wrap items-center gap-2 mt-0.5">
                          <%= if exercise.sets && exercise.reps do %>
                            <span class="text-xs text-base-content/50">
                              {exercise.sets} x {exercise.reps}
                            </span>
                          <% end %>
                          <%= if exercise.duration_seconds do %>
                            <span class="text-xs text-base-content/50 flex items-center gap-1">
                              <.icon name="hero-clock-mini" class="size-3" />
                              {format_duration(exercise.duration_seconds)}
                            </span>
                          <% end %>
                          <%= if exercise.rest_seconds do %>
                            <span class="text-xs text-base-content/40 flex items-center gap-1">
                              <.icon name="hero-pause-mini" class="size-3" />
                              Rest: {format_duration(exercise.rest_seconds)}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
