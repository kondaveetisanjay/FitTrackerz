defmodule FitTrackerzWeb.Trainer.WorkoutsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(page_title: "Workout Plans")
       |> assign(
         no_gym: true,
         workouts: [],
         clients: [],
         gyms: [],
         gym_trainers: [],
         form: nil,
         show_form: false,
         exercises: []
       )}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      workouts = case FitTrackerz.Training.list_workouts_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
        {:ok, workouts} -> workouts
        _ -> []
      end

      clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user]) do
        {:ok, members} -> members
        _ -> []
      end

      form = to_form(%{"name" => "", "member_id" => "", "gym_id" => ""}, as: "workout")

      {:ok,
       socket
       |> assign(page_title: "Workout Plans")
       |> assign(
         no_gym: false,
         workouts: workouts,
         clients: clients,
         gyms: gyms,
         gym_trainers: gym_trainers,
         form: form,
         show_form: false,
         exercises: [blank_exercise(1)]
       )}
    end
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

  @impl true
  def handle_event("validate", %{"workout" => params}, socket) do
    form = to_form(params, as: "workout")
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("add_exercise", _params, socket) do
    exercises = socket.assigns.exercises
    next_order = length(exercises) + 1
    {:noreply, assign(socket, exercises: exercises ++ [blank_exercise(next_order)])}
  end

  @impl true
  def handle_event("remove_exercise", %{"index" => index}, socket) do
    idx = parse_index(index)
    exercises = List.delete_at(socket.assigns.exercises, idx)

    exercises =
      exercises
      |> Enum.with_index(1)
      |> Enum.map(fn {ex, order} -> Map.put(ex, "order", order) end)

    {:noreply, assign(socket, exercises: exercises)}
  end

  @impl true
  def handle_event(
        "update_exercise",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    idx = parse_index(index)

    exercises =
      List.update_at(socket.assigns.exercises, idx, fn ex -> Map.put(ex, field, value) end)

    {:noreply, assign(socket, exercises: exercises)}
  end

  @impl true
  def handle_event("save_workout", %{"workout" => params}, socket) do
    gym_trainers = socket.assigns.gym_trainers
    trainer_ids = Enum.map(gym_trainers, & &1.id)
    gym_trainer = Enum.find(gym_trainers, &(&1.gym_id == params["gym_id"]))

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

    actor = socket.assigns.current_user

    case FitTrackerz.Training.create_workout(%{
      name: params["name"],
      exercises: exercises,
      member_id: params["member_id"],
      gym_id: params["gym_id"],
      trainer_id: gym_trainer && gym_trainer.id
    }, actor: actor) do
      {:ok, _plan} ->
        workouts = case FitTrackerz.Training.list_workouts_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
          {:ok, workouts} -> workouts
          _ -> []
        end

        form = to_form(%{"name" => "", "member_id" => "", "gym_id" => ""}, as: "workout")

        {:noreply,
         socket
         |> assign(
           workouts: workouts,
           form: form,
           show_form: false,
           exercises: [blank_exercise(1)]
         )
         |> put_flash(:info, "Workout plan created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def handle_event("delete_workout", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    trainer_ids = Enum.map(socket.assigns.gym_trainers, & &1.id)

    workout = Enum.find(socket.assigns.workouts, &(&1.id == id))

    if workout do
      case FitTrackerz.Training.destroy_workout(workout, actor: actor) do
        :ok ->
          workouts = case FitTrackerz.Training.list_workouts_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
            {:ok, workouts} -> workouts
            _ -> []
          end

          {:noreply,
           socket
           |> assign(workouts: workouts)
           |> put_flash(:info, "Workout plan deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete workout plan.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Workout plan not found.")}
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
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Workout Plans</h1>
              <p class="text-base-content/50 mt-1">Create and manage workout plans for your clients.</p>
            </div>
          </div>
          <%= unless @no_gym do %>
            <button
              class="btn btn-primary btn-sm gap-2 font-semibold"
              phx-click="toggle_form"
              id="toggle-workout-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> New Workout Plan
            </button>
          <% end %>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-notice">
            <div class="card-body p-8 items-center text-center">
              <div class="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-exclamation-triangle-solid" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Association</h2>
              <p class="text-base-content/50 mt-2 max-w-md">
                You haven't been added to any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Create Form --%>
          <%= if @show_form do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="workout-form-card">
              <div class="card-body p-5">
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
                  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <.input
                      field={@form[:name]}
                      label="Plan Name"
                      placeholder="e.g., Full Body Strength"
                      required
                    />
                    <div>
                      <label class="label"><span class="label-text font-medium">Client</span></label>
                      <select
                        name="workout[member_id]"
                        class="select select-bordered w-full"
                        id="workout-member-select"
                        required
                      >
                        <option value="">Select a client...</option>
                        <option :for={client <- @clients} value={client.id}>
                          {client.user.name}
                        </option>
                      </select>
                    </div>
                    <div>
                      <label class="label"><span class="label-text font-medium">Gym</span></label>
                      <select
                        name="workout[gym_id]"
                        class="select select-bordered w-full"
                        id="workout-gym-select"
                        required
                      >
                        <option value="">Select a gym...</option>
                        <option :for={gym <- @gyms} value={gym.id}>
                          {gym.name}
                        </option>
                      </select>
                    </div>
                  </div>

                  <%!-- Exercises --%>
                  <div class="space-y-3">
                    <div class="flex items-center justify-between">
                      <h3 class="font-semibold text-sm">Exercises</h3>
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs gap-1"
                        phx-click="add_exercise"
                        id="add-exercise-btn"
                      >
                        <.icon name="hero-plus-mini" class="size-3" /> Add Exercise
                      </button>
                    </div>
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
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="remove_exercise"
                            phx-value-index={idx}
                            id={"remove-exercise-#{idx}"}
                          >
                            <.icon name="hero-trash-mini" class="size-3" />
                          </button>
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
                          <label class="label">
                            <span class="label-text text-xs">Duration (s)</span>
                          </label>
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
                          <label class="label">
                            <span class="label-text text-xs">Rest (s)</span>
                          </label>
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
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="toggle_form"
                      id="cancel-workout-btn"
                    >
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="submit-workout-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Create Plan
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Workout Plans Grid --%>
          <%= if @workouts == [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="workouts-empty">
              <div class="card-body p-8 items-center text-center">
                <div class="w-16 h-16 rounded-full bg-accent/10 flex items-center justify-center mb-4">
                  <.icon name="hero-fire-solid" class="size-8 text-accent" />
                </div>
                <h2 class="text-lg font-bold">No Workout Plans Yet</h2>
                <p class="text-base-content/50 mt-2 max-w-md">
                  Create your first workout plan to get started with training your clients.
                </p>
              </div>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="workouts-grid">
              <div
                :for={workout <- @workouts}
                class="card bg-base-200/50 border border-base-300/50"
                id={"workout-card-#{workout.id}"}
              >
                <div class="card-body p-5">
                  <div class="flex items-start justify-between">
                    <h3 class="font-bold text-md">{workout.name}</h3>
                    <button
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="delete_workout"
                      phx-value-id={workout.id}
                      data-confirm="Are you sure you want to delete this workout plan?"
                      id={"delete-workout-#{workout.id}"}
                    >
                      <.icon name="hero-trash-mini" class="size-4" />
                    </button>
                  </div>
                  <div class="space-y-2 mt-2">
                    <div class="flex items-center gap-2 text-sm text-base-content/60">
                      <.icon name="hero-user-mini" class="size-4" />
                      <span>{if workout.member, do: workout.member.user.name, else: "Unassigned"}</span>
                    </div>
                    <div class="flex items-center gap-2 text-sm text-base-content/60">
                      <.icon name="hero-building-office-2-mini" class="size-4" />
                      <span>{if workout.gym, do: workout.gym.name, else: "N/A"}</span>
                    </div>
                    <div class="flex items-center gap-2 text-sm text-base-content/60">
                      <.icon name="hero-list-bullet-mini" class="size-4" />
                      <span>{length(workout.exercises || [])} exercise(s)</span>
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
