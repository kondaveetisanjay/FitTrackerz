defmodule FitTrackerzWeb.Member.WorkoutLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships =
      case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
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
           workout_logs: [],
           current_streak: 0,
           best_streak: 0,
           no_gym: true,
           plan_type: :general,
           show_form: false,
           show_log_form: false,
           log_entries: [],
           log_duration: "",
           log_notes: "",
           new_prs: [],
           selected_plan: nil,
           form: nil,
           exercises: []
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)
        membership = List.first(memberships)

        workout_plans =
          case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
            {:ok, plans} -> plans
            _ -> []
          end

        workout_logs =
          case FitTrackerz.Training.list_workout_logs(mids, actor: actor) do
            {:ok, logs} -> logs
            _ -> []
          end

        {current_streak, best_streak} = calculate_streaks(workout_logs)

        plan_type = determine_plan_type(mids, actor)

        form = to_form(%{"name" => "", "gym_id" => ""}, as: "workout")

        {:ok,
         assign(socket,
           page_title: "My Workout",
           memberships: memberships,
           membership: membership,
           workout_plans: workout_plans,
           workout_logs: workout_logs,
           current_streak: current_streak,
           best_streak: best_streak,
           no_gym: false,
           plan_type: plan_type,
           show_form: false,
           show_log_form: false,
           log_entries: [],
           log_duration: "",
           log_notes: "",
           new_prs: [],
           selected_plan: nil,
           form: form,
           exercises: [blank_exercise(1)]
         )}
    end
  end

  defp determine_plan_type(member_ids, actor) do
    active_sub =
      case FitTrackerz.Billing.list_active_subscriptions_by_member(member_ids,
             actor: actor,
             load: [:subscription_plan]
           ) do
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

  # ── Existing workout plan creation events ──

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

    workout = Enum.find(socket.assigns.workout_plans, fn w -> w.id == id end)

    if workout do
      case FitTrackerz.Training.destroy_workout(workout, actor: actor) do
        :ok ->
          workout_plans =
            case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
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

  # ── Workout logging events ──

  def handle_event("show_log_form", _params, socket) do
    plan = List.first(socket.assigns.workout_plans)

    log_entries =
      if plan do
        (plan.exercises || [])
        |> Enum.sort_by(& &1.order)
        |> Enum.map(fn ex ->
          %{
            name: ex.name,
            planned_sets: ex.sets,
            planned_reps: ex.reps,
            actual_sets: to_string(ex.sets || ""),
            actual_reps: to_string(ex.reps || ""),
            weight_kg: "",
            order: ex.order
          }
        end)
      else
        []
      end

    {:noreply,
     assign(socket,
       show_log_form: true,
       selected_plan: plan,
       log_entries: log_entries,
       log_duration: "",
       log_notes: "",
       new_prs: []
     )}
  end

  def handle_event("cancel_log", _params, socket) do
    {:noreply,
     assign(socket,
       show_log_form: false,
       log_entries: [],
       log_duration: "",
       log_notes: ""
     )}
  end

  def handle_event("update_log_entry", %{"index" => index, "field" => field, "value" => value}, socket) do
    idx = parse_index(index)
    field_atom = String.to_existing_atom(field)

    log_entries =
      List.update_at(socket.assigns.log_entries, idx, fn entry ->
        Map.put(entry, field_atom, value)
      end)

    {:noreply, assign(socket, log_entries: log_entries)}
  end

  def handle_event("update_log_field", %{"field" => "duration", "value" => value}, socket) do
    {:noreply, assign(socket, log_duration: value)}
  end

  def handle_event("update_log_field", %{"field" => "notes", "value" => value}, socket) do
    {:noreply, assign(socket, log_notes: value)}
  end

  def handle_event("save_workout_log", _params, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership
    plan = socket.assigns.selected_plan

    duration =
      case Integer.parse(socket.assigns.log_duration) do
        {n, _} -> n
        :error -> nil
      end

    log_attrs = %{
      member_id: membership.id,
      gym_id: membership.gym_id,
      workout_plan_id: if(plan, do: plan.id, else: nil),
      completed_on: Date.utc_today(),
      duration_minutes: duration,
      notes: if(socket.assigns.log_notes == "", do: nil, else: socket.assigns.log_notes)
    }

    case FitTrackerz.Training.create_workout_log(log_attrs, actor: actor) do
      {:ok, workout_log} ->
        # Create entries and detect PRs
        new_prs =
          socket.assigns.log_entries
          |> Enum.reduce([], fn entry, prs ->
            entry_attrs = %{
              workout_log_id: workout_log.id,
              exercise_name: entry.name,
              planned_sets: entry.planned_sets,
              planned_reps: entry.planned_reps,
              actual_sets: parse_int(entry.actual_sets),
              actual_reps: parse_int(entry.actual_reps),
              weight_kg: parse_decimal(entry.weight_kg),
              order: entry.order
            }

            case FitTrackerz.Training.create_workout_log_entry(entry_attrs, actor: actor) do
              {:ok, _created} ->
                detect_pr(entry, membership.id, actor, prs)

              {:error, _} ->
                prs
            end
          end)

        # Reload logs and recalculate streaks
        mids = Enum.map(socket.assigns.memberships, & &1.id)

        workout_logs =
          case FitTrackerz.Training.list_workout_logs(mids, actor: actor) do
            {:ok, logs} -> logs
            _ -> []
          end

        {current_streak, best_streak} = calculate_streaks(workout_logs)

        {:noreply,
         socket
         |> put_flash(:info, "Workout logged successfully!")
         |> assign(
           workout_logs: workout_logs,
           current_streak: current_streak,
           best_streak: best_streak,
           show_log_form: false,
           log_entries: [],
           log_duration: "",
           log_notes: "",
           new_prs: new_prs
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("dismiss_prs", _params, socket) do
    {:noreply, assign(socket, new_prs: [])}
  end

  # ── Private helpers ──

  defp detect_pr(entry, member_id, actor, prs) do
    weight = parse_decimal(entry.weight_kg)

    if weight && Decimal.gt?(weight, Decimal.new(0)) do
      case FitTrackerz.Training.get_exercise_pr(member_id, entry.name, actor: actor) do
        {:ok, [prev_best | _]} ->
          if Decimal.gt?(weight, prev_best.weight_kg) do
            [
              %{
                exercise: entry.name,
                new_weight: Decimal.to_string(weight, :normal),
                previous_weight: Decimal.to_string(prev_best.weight_kg, :normal)
              }
              | prs
            ]
          else
            prs
          end

        {:ok, []} ->
          # First time logging weight for this exercise — it's a PR
          [
            %{
              exercise: entry.name,
              new_weight: Decimal.to_string(weight, :normal),
              previous_weight: nil
            }
            | prs
          ]

        _ ->
          prs
      end
    else
      prs
    end
  end

  defp handle_save_workout(params, memberships, socket) do
    membership =
      Enum.find(memberships, List.first(memberships), &(&1.gym_id == params["gym_id"]))

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

    case FitTrackerz.Training.create_workout(
           %{
             name: params["name"],
             exercises: exercises,
             member_id: membership.id,
             gym_id: gym_id
           },
           actor: actor
         ) do
      {:ok, _plan} ->
        mids = Enum.map(memberships, & &1.id)

        workout_plans =
          case FitTrackerz.Training.list_workouts_by_member(mids, actor: actor, load: [:gym]) do
            {:ok, plans} -> plans
            _ -> []
          end

        form = to_form(%{"name" => "", "gym_id" => ""}, as: "workout")

        {:noreply,
         socket
         |> assign(
           workout_plans: workout_plans,
           form: form,
           show_form: false,
           exercises: [blank_exercise(1)]
         )
         |> put_flash(:info, "Workout plan created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  # ── Streak calculation ──

  defp calculate_streaks(workout_logs) do
    dates =
      workout_logs
      |> Enum.map(& &1.completed_on)
      |> Enum.uniq()
      |> Enum.sort(Date)
      |> Enum.reverse()

    current = calculate_current_streak(dates, Date.utc_today())
    best = calculate_best_streak(Enum.reverse(dates))
    {current, best}
  end

  defp calculate_current_streak([], _today), do: 0

  defp calculate_current_streak([latest | rest], today) do
    diff = Date.diff(today, latest)
    if diff > 1, do: 0, else: count_consecutive([latest | rest], 1)
  end

  defp count_consecutive([_], count), do: count

  defp count_consecutive([a, b | rest], count) do
    if Date.diff(a, b) == 1, do: count_consecutive([b | rest], count + 1), else: count
  end

  defp calculate_best_streak([]), do: 0

  defp calculate_best_streak(dates) do
    dates
    |> Enum.chunk_while(
      [],
      fn date, acc ->
        case acc do
          [] ->
            {:cont, [date]}

          [prev | _] ->
            if Date.diff(date, prev) == 1, do: {:cont, [date | acc]}, else: {:cont, acc, [date]}
        end
      end,
      fn acc -> {:cont, acc, []} end
    )
    |> Enum.map(&length/1)
    |> Enum.max(fn -> 0 end)
  end

  # ── Parsing helpers ──

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

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil

  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> d
      :error -> nil
    end
  end

  defp parse_decimal(%Decimal{} = d), do: d

  defp format_duration(nil), do: nil

  defp format_duration(seconds) when seconds >= 60,
    do: "#{div(seconds, 60)}m #{rem(seconds, 60)}s"

  defp format_duration(seconds), do: "#{seconds}s"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <.page_header
          title="My Workout"
          subtitle={if @plan_type == :general, do: "Create, manage, and log your workout programs.", else: "View and log your personalized workout programs."}
          back_path="/member"
        >
          <:actions>
            <div class="flex gap-2">
              <%= if not @no_gym and @workout_plans != [] and not @show_log_form do %>
                <.button variant="primary" size="sm" icon="hero-check-circle" phx-click="show_log_form" id="log-workout-btn" class="btn-success">
                  Log Today's Workout
                </.button>
              <% end %>
              <%= if @plan_type == :general and not @no_gym do %>
                <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form" id="toggle-workout-form-btn">
                  New Workout Plan
                </.button>
              <% end %>
            </div>
          </:actions>
        </.page_header>

        <%= if @no_gym do %>
          <.empty_state
            icon="hero-building-office-2"
            title="No Gym Membership"
            subtitle="You haven't joined any gym yet. Ask a gym operator to invite you."
          />
        <% else %>
          <%!-- Streak Counters --%>
          <div class="grid grid-cols-2 gap-4" id="streak-section">
            <.stat_card
              label="Current Streak"
              value={"#{@current_streak} days"}
              icon="hero-fire-solid"
              color="warning"
            />
            <.stat_card
              label="Best Streak"
              value={"#{@best_streak} days"}
              icon="hero-trophy-solid"
              color="accent"
            />
          </div>

          <%!-- PR Alerts --%>
          <%= if @new_prs != [] do %>
            <.alert variant="success" dismissible id="pr-alerts">
              <div>
                <h2 class="text-lg font-bold flex items-center gap-2 text-success">
                  <.icon name="hero-trophy-solid" class="size-5" /> New Personal Records!
                </h2>
                <div class="mt-3 space-y-2">
                  <div
                    :for={pr <- @new_prs}
                    class="flex items-center gap-3 p-3 rounded-lg bg-success/5"
                  >
                    <div class="w-8 h-8 rounded-lg bg-success/20 flex items-center justify-center shrink-0">
                      <.icon name="hero-arrow-trending-up-solid" class="size-4 text-success" />
                    </div>
                    <div>
                      <span class="font-semibold text-sm">{pr.exercise}</span>
                      <span class="text-sm text-base-content/60">
                        -- {pr.new_weight} kg
                        <%= if pr.previous_weight do %>
                          <span class="text-base-content/40">(prev: {pr.previous_weight} kg)</span>
                        <% else %>
                          <span class="text-base-content/40">(first record!)</span>
                        <% end %>
                      </span>
                    </div>
                  </div>
                </div>
                <.button variant="ghost" size="sm" phx-click="dismiss_prs" id="dismiss-prs-btn" class="mt-2">
                  Dismiss
                </.button>
              </div>
            </.alert>
          <% end %>

          <%!-- Log Workout Form --%>
          <%= if @show_log_form do %>
            <.card title="Log Workout" id="log-form-card">
              <%= if @selected_plan do %>
                <p class="text-sm text-base-content/50 mt-1">
                  Logging against: <span class="font-semibold text-base-content/70">{@selected_plan.name}</span>
                </p>
              <% end %>

              <div class="mt-4 overflow-x-auto">
                <table class="table table-sm" id="log-entries-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Exercise</th>
                      <th>Plan</th>
                      <th>Actual Sets</th>
                      <th>Actual Reps</th>
                      <th>Weight (kg)</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {entry, idx} <- Enum.with_index(@log_entries) do %>
                      <tr id={"log-entry-#{idx}"}>
                        <td class="font-medium text-sm">{entry.name}</td>
                        <td class="text-sm text-base-content/50">
                          {entry.planned_sets || "-"} x {entry.planned_reps || "-"}
                        </td>
                        <td>
                          <input type="number" value={entry.actual_sets} class="input input-bordered input-sm w-20" phx-blur="update_log_entry" phx-value-index={idx} phx-value-field="actual_sets" id={"log-sets-#{idx}"} min="0" />
                        </td>
                        <td>
                          <input type="number" value={entry.actual_reps} class="input input-bordered input-sm w-20" phx-blur="update_log_entry" phx-value-index={idx} phx-value-field="actual_reps" id={"log-reps-#{idx}"} min="0" />
                        </td>
                        <td>
                          <input type="number" value={entry.weight_kg} class="input input-bordered input-sm w-24" phx-blur="update_log_entry" phx-value-index={idx} phx-value-field="weight_kg" id={"log-weight-#{idx}"} step="0.5" min="0" placeholder="0" />
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-4">
                <div>
                  <label class="label"><span class="label-text font-medium">Duration (minutes)</span></label>
                  <input type="number" value={@log_duration} class="input input-bordered input-sm w-full" phx-blur="update_log_field" phx-value-field="duration" id="log-duration" min="1" placeholder="e.g., 45" />
                </div>
                <div>
                  <label class="label"><span class="label-text font-medium">Notes</span></label>
                  <input type="text" value={@log_notes} class="input input-bordered input-sm w-full" phx-blur="update_log_field" phx-value-field="notes" id="log-notes" placeholder="How did it feel?" />
                </div>
              </div>

              <div class="flex justify-end gap-2 pt-4">
                <.button variant="ghost" size="sm" type="button" phx-click="cancel_log" id="cancel-log-btn">Cancel</.button>
                <.button variant="primary" size="sm" icon="hero-check" type="button" phx-click="save_workout_log" id="complete-workout-btn" class="btn-success">
                  Complete Workout
                </.button>
              </div>
            </.card>
          <% end %>

          <%!-- Create Plan Form (General only) --%>
          <%= if @plan_type == :general and @show_form do %>
            <.card title="New Workout Plan" id="workout-form-card">
              <.form
                for={@form}
                id="workout-form"
                phx-change="validate"
                phx-submit="save_workout"
                class="space-y-4"
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
                <.section title="Exercises">
                  <:actions>
                    <.button variant="ghost" size="sm" icon="hero-plus" type="button" phx-click="add_exercise" id="add-exercise-btn">
                      Add Exercise
                    </.button>
                  </:actions>
                  <div class="space-y-3">
                    <div
                      :for={{exercise, idx} <- Enum.with_index(@exercises)}
                      class="p-4 rounded-lg bg-base-300/20 space-y-3"
                      id={"exercise-row-#{idx}"}
                    >
                      <div class="flex items-center justify-between">
                        <span class="text-xs font-semibold text-base-content/40 uppercase">
                          Exercise #{idx + 1}
                        </span>
                        <%= if length(@exercises) > 1 do %>
                          <.button variant="ghost" size="sm" type="button" phx-click="remove_exercise" phx-value-index={idx} id={"remove-exercise-#{idx}"} class="text-error">
                            <.icon name="hero-trash-mini" class="size-3" />
                          </.button>
                        <% end %>
                      </div>
                      <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
                        <div class="col-span-2 sm:col-span-1">
                          <label class="label"><span class="label-text text-xs">Name</span></label>
                          <input type="text" value={exercise["name"]} placeholder="e.g., Squats" class="input input-bordered input-sm w-full" phx-blur="update_exercise" phx-value-index={idx} phx-value-field="name" id={"exercise-name-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Sets</span></label>
                          <input type="number" value={exercise["sets"]} placeholder="3" class="input input-bordered input-sm w-full" phx-blur="update_exercise" phx-value-index={idx} phx-value-field="sets" id={"exercise-sets-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Reps</span></label>
                          <input type="number" value={exercise["reps"]} placeholder="12" class="input input-bordered input-sm w-full" phx-blur="update_exercise" phx-value-index={idx} phx-value-field="reps" id={"exercise-reps-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Duration (s)</span></label>
                          <input type="number" value={exercise["duration_seconds"]} placeholder="60" class="input input-bordered input-sm w-full" phx-blur="update_exercise" phx-value-index={idx} phx-value-field="duration_seconds" id={"exercise-duration-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Rest (s)</span></label>
                          <input type="number" value={exercise["rest_seconds"]} placeholder="30" class="input input-bordered input-sm w-full" phx-blur="update_exercise" phx-value-index={idx} phx-value-field="rest_seconds" id={"exercise-rest-#{idx}"} />
                        </div>
                      </div>
                    </div>
                  </div>
                </.section>

                <div class="flex justify-end gap-2 pt-2">
                  <.button variant="ghost" size="sm" type="button" phx-click="toggle_form" id="cancel-workout-btn">Cancel</.button>
                  <.button variant="primary" size="sm" icon="hero-check" type="submit" id="submit-workout-btn">Create Plan</.button>
                </div>
              </.form>
            </.card>
          <% end %>

          <%!-- Workout Plans --%>
          <%= if @workout_plans == [] do %>
            <.empty_state
              icon="hero-fire"
              title="No Workout Plans Yet"
              subtitle={if @plan_type == :general, do: "Create your first workout plan to start your fitness journey!", else: "Your trainer will assign a workout plan tailored for you. Check back soon!"}
            />
          <% else %>
            <.section title="Workout Plans">
              <:actions>
                <.badge variant="neutral" size="sm">{length(@workout_plans)}</.badge>
              </:actions>
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <div
                  :for={plan <- @workout_plans}
                  id={"workout-plan-#{plan.id}"}
                >
                  <.card>
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <h3 class="text-lg font-bold flex items-center gap-2">
                          <.icon name="hero-fire-solid" class="size-5 text-accent" />
                          {plan.name}
                        </h3>
                        <div class="flex flex-wrap items-center gap-3 mt-2 text-xs text-base-content/50">
                          <%= if plan.gym do %>
                            <span class="flex items-center gap-1">
                              <.icon name="hero-building-office-2-mini" class="size-3" />
                              {plan.gym.name}
                            </span>
                          <% end %>
                          <.badge variant="neutral" size="sm">
                            <%= if @plan_type == :general, do: "Self-created", else: "Trainer assigned" %>
                          </.badge>
                        </div>
                      </div>
                      <div class="flex items-center gap-2">
                        <.badge variant="secondary" size="sm">
                          {length(plan.exercises || [])} exercises
                        </.badge>
                        <%= if @plan_type == :general do %>
                          <.button
                            variant="ghost"
                            size="sm"
                            phx-click="delete_workout"
                            phx-value-id={plan.id}
                            data-confirm="Are you sure you want to delete this workout plan?"
                            id={"delete-workout-#{plan.id}"}
                            class="text-error"
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
                  </.card>
                </div>
              </div>
            </.section>
          <% end %>

          <%!-- Workout History --%>
          <.card title="Workout History" id="workout-history-card">
            <:header_actions>
              <.badge variant="neutral" size="sm">{length(@workout_logs)}</.badge>
            </:header_actions>
            <%= if @workout_logs == [] do %>
              <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                <p class="text-sm text-base-content/50">No workouts logged yet. Complete your first workout above!</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for log <- @workout_logs do %>
                  <div
                    class="flex items-center justify-between p-3 rounded-lg bg-base-300/20"
                    id={"log-#{log.id}"}
                  >
                    <div class="flex items-center gap-3">
                      <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-check-circle-solid" class="size-4 text-primary" />
                      </div>
                      <div>
                        <p class="text-sm font-semibold">
                          {Calendar.strftime(log.completed_on, "%b %d, %Y")}
                        </p>
                        <div class="flex flex-wrap items-center gap-2 mt-0.5">
                          <%= if log.workout_plan do %>
                            <span class="text-xs text-base-content/50">{log.workout_plan.name}</span>
                          <% end %>
                          <%= if log.duration_minutes do %>
                            <.badge variant="neutral" size="sm">{log.duration_minutes} min</.badge>
                          <% end %>
                          <%= if log.entries && length(log.entries) > 0 do %>
                            <.badge variant="neutral" size="sm">{length(log.entries)} exercises</.badge>
                          <% end %>
                        </div>
                      </div>
                    </div>
                    <%= if log.notes do %>
                      <span class="text-xs text-base-content/40 max-w-[200px] truncate">{log.notes}</span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
