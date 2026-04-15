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
      <.page_header title="Workout Plans" subtitle="Create and manage workout plans for your clients." back_path="/trainer">
        <:actions>
          <%= unless @no_gym do %>
            <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form" id="toggle-workout-form-btn">
              New Workout Plan
            </.button>
          <% end %>
        </:actions>
      </.page_header>

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Create Form --%>
        <%= if @show_form do %>
          <div class="mb-8">
            <.card title="New Workout Plan">
              <.form
                for={@form}
                id="workout-form"
                phx-change="validate"
                phx-submit="save_workout"
                class="space-y-4"
              >
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <.input
                    field={@form[:name]}
                    label="Plan Name"
                    placeholder="e.g., Full Body Strength"
                  />
                  <div>
                    <label class="label"><span class="label-text font-medium">Client</span></label>
                    <select
                      name="workout[member_id]"
                      class="select select-bordered w-full"
                      id="workout-member-select"
                    >
                      <option value="" selected={@form[:member_id].value in [nil, ""]}>Select a client...</option>
                      <option
                        :for={client <- @clients}
                        value={client.id}
                        selected={@form[:member_id].value == client.id}
                      >
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
                    >
                      <option value="" selected={@form[:gym_id].value in [nil, ""]}>Select a gym...</option>
                      <option
                        :for={gym <- @gyms}
                        value={gym.id}
                        selected={@form[:gym_id].value == gym.id}
                      >
                        {gym.name}
                      </option>
                    </select>
                  </div>
                </div>

                <%!-- Exercises --%>
                <div class="space-y-3">
                  <div class="flex items-center justify-between">
                    <h3 class="font-semibold text-sm">Exercises</h3>
                    <.button type="button" variant="ghost" size="sm" icon="hero-plus" phx-click="add_exercise" id="add-exercise-btn">
                      Add Exercise
                    </.button>
                  </div>
                  <div
                    :for={{exercise, idx} <- Enum.with_index(@exercises)}
                    class="p-4 rounded-lg bg-base-200/50 space-y-3"
                    id={"exercise-row-#{idx}"}
                  >
                    <div class="flex items-center justify-between">
                      <span class="text-xs font-semibold text-base-content/40 uppercase">
                        Exercise #{idx + 1}
                      </span>
                      <%= if length(@exercises) > 1 do %>
                        <.button
                          type="button"
                          variant="ghost"
                          size="sm"
                          icon="hero-trash"
                          phx-click="remove_exercise"
                          phx-value-index={idx}
                          id={"remove-exercise-#{idx}"}
                          class="text-error"
                        >
                          <span class="sr-only">Remove</span>
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
                  <.button type="button" variant="ghost" size="sm" phx-click="toggle_form" id="cancel-workout-btn">
                    Cancel
                  </.button>
                  <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-workout-btn">
                    Create Plan
                  </.button>
                </div>
              </.form>
            </.card>
          </div>
        <% end %>

        <%!-- Workout Plans --%>
        <%= if @workouts == [] do %>
          <.empty_state
            icon="hero-fire"
            title="No Workout Plans Yet"
            subtitle="Create your first workout plan to get started with training your clients."
          >
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form">
                Create Workout Plan
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <.data_table id="workouts-table" rows={@workouts} row_id={fn w -> "workout-#{w.id}" end}>
            <:col :let={workout} label="Plan Name">
              <span class="font-bold">{workout.name}</span>
            </:col>
            <:col :let={workout} label="Client">
              <div class="flex items-center gap-2">
                <%= if workout.member do %>
                  <.avatar name={workout.member.user.name} size="sm" />
                  <span>{workout.member.user.name}</span>
                <% else %>
                  <span class="text-base-content/40">Unassigned</span>
                <% end %>
              </div>
            </:col>
            <:col :let={workout} label="Gym">
              {if workout.gym, do: workout.gym.name, else: "N/A"}
            </:col>
            <:col :let={workout} label="Exercises">
              <.badge variant="neutral">{length(workout.exercises || [])} exercise(s)</.badge>
            </:col>
            <:actions :let={workout}>
              <.button
                variant="danger"
                size="sm"
                icon="hero-trash"
                phx-click="delete_workout"
                phx-value-id={workout.id}
                data-confirm="Are you sure you want to delete this workout plan?"
              >
                <span class="sr-only">Delete</span>
              </.button>
            </:actions>
            <:mobile_card :let={workout}>
              <div>
                <p class="font-bold">{workout.name}</p>
                <p class="text-xs text-base-content/50 mt-1">
                  {if workout.member, do: workout.member.user.name, else: "Unassigned"} &middot;
                  {length(workout.exercises || [])} exercise(s)
                </p>
              </div>
            </:mobile_card>
          </.data_table>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
