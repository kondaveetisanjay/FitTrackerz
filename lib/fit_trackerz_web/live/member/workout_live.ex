defmodule FitTrackerzWeb.Member.WorkoutLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My Workout",
           memberships: [],
           workout_plans: [],
           no_gym: true,
           plan_type: :general,
           show_form: false,
           form: nil,
           exercises: []
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)

        workout_plans = case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
          {:ok, plans} -> plans
          _ -> []
        end

        plan_type = determine_plan_type(mids, actor)

        form = to_form(%{"name" => "", "gym_id" => ""}, as: "workout")

        {:ok,
         assign(socket,
           page_title: "My Workout",
           memberships: memberships,
           workout_plans: workout_plans,
           no_gym: false,
           plan_type: plan_type,
           show_form: false,
           form: form,
           exercises: [blank_exercise(1)]
         )}
    end
  end

  defp determine_plan_type(member_ids, actor) do
    active_sub = case FitTrackerz.Billing.list_active_subscriptions_by_member(member_ids, actor: actor, load: [:subscription_plan]) do
      {:ok, subs} -> List.first(subs)
      _ -> nil
    end

    if active_sub && active_sub.subscription_plan,
      do: active_sub.subscription_plan.plan_type,
      else: :general
  end

  defp blank_exercise(order) do
    %{
      "name" => "",
      "sets" => "",
      "reps" => "",
      "duration_seconds" => "",
      "rest_seconds" => "",
      "order" => order
    }
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("validate", %{"workout" => params}, socket) do
    form = to_form(params, as: "workout")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("add_exercise", _params, socket) do
    exercises = socket.assigns.exercises
    next_order = length(exercises) + 1
    {:noreply, assign(socket, exercises: exercises ++ [blank_exercise(next_order)])}
  end

  def handle_event("remove_exercise", %{"index" => index}, socket) do
    idx = parse_index(index)
    exercises = List.delete_at(socket.assigns.exercises, idx)

    exercises =
      exercises
      |> Enum.with_index(1)
      |> Enum.map(fn {ex, order} -> Map.put(ex, "order", order) end)

    {:noreply, assign(socket, exercises: exercises)}
  end

  def handle_event("update_exercise", %{"index" => index, "field" => field, "value" => value}, socket) do
    idx = parse_index(index)

    exercises =
      List.update_at(socket.assigns.exercises, idx, fn ex -> Map.put(ex, field, value) end)

    {:noreply, assign(socket, exercises: exercises)}
  end

  def handle_event("save_workout", %{"workout" => params}, socket) do
    memberships = socket.assigns.memberships

    if memberships == [] do
      {:noreply, put_flash(socket, :error, "No active membership found.")}
    else
      handle_save_workout(params, memberships, socket)
    end
  end

  def handle_event("delete_workout", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    memberships = socket.assigns.memberships
    mids = Enum.map(memberships, & &1.id)

    workout = Enum.find(socket.assigns.workout_plans, fn w ->
      w.id == id
    end)

    if workout do
      case FitTrackerz.Training.destroy_workout(workout, actor: actor) do
        :ok ->
          workout_plans = case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
            {:ok, plans} -> plans
            _ -> []
          end

          {:noreply,
           socket
           |> assign(workout_plans: workout_plans)
           |> put_flash(:info, "Workout plan deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete workout plan.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Workout plan not found.")}
    end
  end

  defp handle_save_workout(params, memberships, socket) do
    membership = Enum.find(memberships, List.first(memberships), &(&1.gym_id == params["gym_id"]))

    exercises =
      socket.assigns.exercises
      |> Enum.map(fn ex ->
        %{
          name: ex["name"],
          sets: parse_int(ex["sets"]),
          reps: parse_int(ex["reps"]),
          duration_seconds: parse_int(ex["duration_seconds"]),
          rest_seconds: parse_int(ex["rest_seconds"]),
          order: ex["order"]
        }
      end)
      |> Enum.reject(fn ex -> ex.name == "" or ex.name == nil end)

    gym_id = if params["gym_id"] != "", do: params["gym_id"], else: membership.gym_id

    actor = socket.assigns.current_user

    case FitTrackerz.Training.create_workout(%{
      name: params["name"],
      exercises: exercises,
      member_id: membership.id,
      gym_id: gym_id
    }, actor: actor) do
      {:ok, _plan} ->
        mids = Enum.map(memberships, & &1.id)

        workout_plans = case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
          {:ok, plans} -> plans
          _ -> []
        end

        form = to_form(%{"name" => "", "gym_id" => ""}, as: "workout")

        {:noreply,
         socket
         |> assign(workout_plans: workout_plans, form: form, show_form: false, exercises: [blank_exercise(1)])
         |> put_flash(:info, "Workout plan created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  defp parse_index(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val

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
              <h1 class="text-2xl sm:text-3xl font-brand">My Workout Plans</h1>
              <p class="text-base-content/50 mt-1">
                <%= if @plan_type == :general do %>
                  Create and manage your own workout programs.
                <% else %>
                  View your personalized workout programs.
                <% end %>
              </p>
            </div>
          </div>
          <%= if @plan_type == :general and not @no_gym do %>
            <.button
              class="btn-primary btn-sm gap-2 font-semibold press-scale"
              phx-click="toggle_form"
              id="toggle-workout-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> New Workout Plan
            </.button>
          <% end %>
        </div>

        <%= if @no_gym do %>
          <div class="ft-card p-6" id="no-gym-card">
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
          <%!-- Create Form (General only) --%>
          <%= if @plan_type == :general and @show_form do %>
            <div class="ft-card p-6" id="workout-form-card">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-fire-solid" class="size-5 text-accent" /> New Workout Plan
              </h2>
              <.form
                for={@form}
                id="workout-form"
                phx-change="validate"
                phx-submit="save_workout"
                class="mt-4 space-y-4"
              >
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <.input
                    field={@form[:name]}
                    label="Plan Name"
                    placeholder="e.g., Full Body Strength"
                    required
                  />
                  <div>
                    <label class="label"><span class="label-text font-medium">Gym</span></label>
                    <select
                      name="workout[gym_id]"
                      class="select select-bordered w-full"
                      id="workout-gym-select"
                      required
                    >
                      <option value="">Select a gym...</option>
                      <option :for={m <- @memberships} value={m.gym_id}>
                        {m.gym.name}
                      </option>
                    </select>
                  </div>
                </div>

                <%!-- Exercises --%>
                <div class="space-y-3">
                  <div class="flex items-center justify-between">
                    <h3 class="font-semibold text-sm">Exercises</h3>
                    <.button
                      type="button"
                      class="btn-ghost btn-xs gap-1 press-scale"
                      phx-click="add_exercise"
                      id="add-exercise-btn"
                    >
                      <.icon name="hero-plus-mini" class="size-3" /> Add Exercise
                    </.button>
                  </div>
                  <div
                    :for={{exercise, idx} <- Enum.with_index(@exercises)}
                    class="p-4 rounded-xl bg-base-200/30 space-y-3"
                    id={"exercise-row-#{idx}"}
                  >
                    <div class="flex items-center justify-between">
                      <span class="text-xs font-semibold text-base-content/40 uppercase">
                        Exercise #{idx + 1}
                      </span>
                      <%= if length(@exercises) > 1 do %>
                        <.button
                          type="button"
                          class="btn-ghost btn-xs text-error press-scale"
                          phx-click="remove_exercise"
                          phx-value-index={idx}
                          id={"remove-exercise-#{idx}"}
                        >
                          <.icon name="hero-trash-mini" class="size-3" />
                        </.button>
                      <% end %>
                    </div>
                    <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
                      <div class="col-span-2 sm:col-span-1">
                        <label class="label"><span class="label-text text-xs">Name</span></label>
                        <input
                          type="text"
                          value={exercise["name"]}
                          placeholder="e.g., Squats"
                          class="input input-bordered input-sm w-full"
                          phx-blur="update_exercise"
                          phx-value-index={idx}
                          phx-value-field="name"
                          id={"exercise-name-#{idx}"}
                        />
                      </div>
                      <div>
                        <label class="label"><span class="label-text text-xs">Sets</span></label>
                        <input
                          type="number"
                          value={exercise["sets"]}
                          placeholder="3"
                          class="input input-bordered input-sm w-full"
                          phx-blur="update_exercise"
                          phx-value-index={idx}
                          phx-value-field="sets"
                          id={"exercise-sets-#{idx}"}
                        />
                      </div>
                      <div>
                        <label class="label"><span class="label-text text-xs">Reps</span></label>
                        <input
                          type="number"
                          value={exercise["reps"]}
                          placeholder="12"
                          class="input input-bordered input-sm w-full"
                          phx-blur="update_exercise"
                          phx-value-index={idx}
                          phx-value-field="reps"
                          id={"exercise-reps-#{idx}"}
                        />
                      </div>
                      <div>
                        <label class="label"><span class="label-text text-xs">Duration (s)</span></label>
                        <input
                          type="number"
                          value={exercise["duration_seconds"]}
                          placeholder="60"
                          class="input input-bordered input-sm w-full"
                          phx-blur="update_exercise"
                          phx-value-index={idx}
                          phx-value-field="duration_seconds"
                          id={"exercise-duration-#{idx}"}
                        />
                      </div>
                      <div>
                        <label class="label"><span class="label-text text-xs">Rest (s)</span></label>
                        <input
                          type="number"
                          value={exercise["rest_seconds"]}
                          placeholder="30"
                          class="input input-bordered input-sm w-full"
                          phx-blur="update_exercise"
                          phx-value-index={idx}
                          phx-value-field="rest_seconds"
                          id={"exercise-rest-#{idx}"}
                        />
                      </div>
                    </div>
                  </div>
                </div>

                <div class="flex justify-end gap-2 pt-2">
                  <.button type="button" class="btn-ghost btn-sm press-scale" phx-click="toggle_form" id="cancel-workout-btn">
                    Cancel
                  </.button>
                  <.button type="submit" class="btn-primary btn-sm gap-2" id="submit-workout-btn">
                    <.icon name="hero-check-mini" class="size-4" /> Create Plan
                  </.button>
                </div>
              </.form>
            </div>
          <% end %>

          <%= if @workout_plans == [] do %>
            <div class="ft-card p-6" id="no-workout-plans">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-accent/10 flex items-center justify-center mb-4">
                  <.icon name="hero-fire" class="size-8 text-accent" />
                </div>
                <h2 class="text-lg font-bold">No Workout Plans Yet</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  <%= if @plan_type == :general do %>
                    Create your first workout plan to start your fitness journey!
                  <% else %>
                    Your gym operator will assign a workout plan tailored for you. Check back soon!
                  <% end %>
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Workout Plan Cards --%>
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div
                :for={plan <- @workout_plans}
                class="ft-card p-6"
                id={"workout-plan-#{plan.id}"}
              >
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
                      <span class="badge badge-ghost badge-xs">Self-created</span>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="badge badge-accent badge-outline badge-sm">
                      {length(plan.exercises || [])} exercises
                    </div>
                    <%= if @plan_type == :general do %>
                      <.button
                        class="btn-ghost btn-xs text-error press-scale"
                        phx-click="delete_workout"
                        phx-value-id={plan.id}
                        data-confirm="Are you sure you want to delete this workout plan?"
                        id={"delete-workout-#{plan.id}"}
                      >
                        <.icon name="hero-trash-mini" class="size-4" />
                      </.button>
                    <% end %>
                  </div>
                </div>

                <%!-- Exercises --%>
                <div class="mt-4 space-y-2">
                  <div
                    :for={exercise <- Enum.sort_by(plan.exercises || [], & &1.order)}
                    class="flex items-center gap-3 p-3 bg-base-200/30 rounded-xl"
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
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
