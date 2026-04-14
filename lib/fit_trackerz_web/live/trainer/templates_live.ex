defmodule FitTrackerzWeb.Trainer.TemplatesLive do
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
       |> assign(page_title: "Templates")
       |> assign(
         no_gym: true,
         workout_templates: [],
         diet_templates: [],
         gyms: [],
         workout_form: nil,
         diet_form: nil,
         show_workout_form: false,
         show_diet_form: false
       )}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      gym_ids = Enum.map(gyms, & &1.id)

      workout_templates =
        gym_ids
        |> Enum.flat_map(fn gid ->
          case FitTrackerz.Training.list_workout_templates_by_gym(gid, actor: actor) do
            {:ok, templates} -> templates
            _ -> []
          end
        end)
        |> Enum.filter(&(&1.created_by_id == actor.id))

      diet_templates =
        gym_ids
        |> Enum.flat_map(fn gid ->
          case FitTrackerz.Training.list_diet_templates_by_gym(gid, actor: actor) do
            {:ok, templates} -> templates
            _ -> []
          end
        end)
        |> Enum.filter(&(&1.created_by_id == actor.id))

      workout_form =
        to_form(%{"name" => "", "difficulty_level" => "", "gym_id" => ""}, as: "workout_template")

      diet_form =
        to_form(%{"name" => "", "calorie_target" => "", "dietary_type" => "", "gym_id" => ""},
          as: "diet_template"
        )

      {:ok,
       socket
       |> assign(page_title: "Templates")
       |> assign(
         no_gym: false,
         workout_templates: workout_templates,
         diet_templates: diet_templates,
         gyms: gyms,
         workout_form: workout_form,
         diet_form: diet_form,
         show_workout_form: false,
         show_diet_form: false
       )}
    end
  end

  @impl true
  def handle_event("toggle_workout_form", _params, socket) do
    {:noreply, assign(socket, show_workout_form: !socket.assigns.show_workout_form)}
  end

  @impl true
  def handle_event("toggle_diet_form", _params, socket) do
    {:noreply, assign(socket, show_diet_form: !socket.assigns.show_diet_form)}
  end

  @impl true
  def handle_event("validate_workout_template", %{"workout_template" => params}, socket) do
    form = to_form(params, as: "workout_template")
    {:noreply, assign(socket, workout_form: form)}
  end

  @impl true
  def handle_event("validate_diet_template", %{"diet_template" => params}, socket) do
    form = to_form(params, as: "diet_template")
    {:noreply, assign(socket, diet_form: form)}
  end

  @impl true
  def handle_event("save_workout_template", %{"workout_template" => params}, socket) do
    actor = socket.assigns.current_user

    difficulty_level =
      case params["difficulty_level"] do
        "" -> nil
        val -> String.to_existing_atom(val)
      end

    case FitTrackerz.Training.create_workout_template(%{
      name: params["name"],
      difficulty_level: difficulty_level,
      gym_id: params["gym_id"],
      created_by_id: actor.id
    }, actor: actor) do
      {:ok, _template} ->
        workout_templates = reload_workout_templates(socket.assigns.gyms, actor)

        workout_form =
          to_form(%{"name" => "", "difficulty_level" => "", "gym_id" => ""},
            as: "workout_template"
          )

        {:noreply,
         socket
         |> assign(
           workout_templates: workout_templates,
           workout_form: workout_form,
           show_workout_form: false
         )
         |> put_flash(:info, "Workout template created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def handle_event("save_diet_template", %{"diet_template" => params}, socket) do
    actor = socket.assigns.current_user

    calorie_target =
      case Integer.parse(params["calorie_target"] || "") do
        {val, _} -> val
        :error -> nil
      end

    dietary_type =
      case params["dietary_type"] do
        "" -> nil
        val -> String.to_existing_atom(val)
      end

    case FitTrackerz.Training.create_diet_template(%{
      name: params["name"],
      calorie_target: calorie_target,
      dietary_type: dietary_type,
      gym_id: params["gym_id"],
      created_by_id: actor.id
    }, actor: actor) do
      {:ok, _template} ->
        diet_templates = reload_diet_templates(socket.assigns.gyms, actor)

        diet_form =
          to_form(%{"name" => "", "calorie_target" => "", "dietary_type" => "", "gym_id" => ""},
            as: "diet_template"
          )

        {:noreply,
         socket
         |> assign(diet_templates: diet_templates, diet_form: diet_form, show_diet_form: false)
         |> put_flash(:info, "Diet template created successfully.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  @impl true
  def handle_event("delete_workout_template", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    template = Enum.find(socket.assigns.workout_templates, &(&1.id == id))

    if template do
      case FitTrackerz.Training.destroy_workout_template(template, actor: actor) do
        :ok ->
          workout_templates = reload_workout_templates(socket.assigns.gyms, actor)

          {:noreply,
           socket
           |> assign(workout_templates: workout_templates)
           |> put_flash(:info, "Workout template deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete template.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Template not found.")}
    end
  end

  @impl true
  def handle_event("delete_diet_template", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    template = Enum.find(socket.assigns.diet_templates, &(&1.id == id))

    if template do
      case FitTrackerz.Training.destroy_diet_template(template, actor: actor) do
        :ok ->
          diet_templates = reload_diet_templates(socket.assigns.gyms, actor)

          {:noreply,
           socket
           |> assign(diet_templates: diet_templates)
           |> put_flash(:info, "Diet template deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete template.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Template not found.")}
    end
  end

  defp reload_workout_templates(gyms, actor) do
    gym_ids = Enum.map(gyms, & &1.id)

    gym_ids
    |> Enum.flat_map(fn gid ->
      case FitTrackerz.Training.list_workout_templates_by_gym(gid, actor: actor) do
        {:ok, templates} -> templates
        _ -> []
      end
    end)
    |> Enum.filter(&(&1.created_by_id == actor.id))
  end

  defp reload_diet_templates(gyms, actor) do
    gym_ids = Enum.map(gyms, & &1.id)

    gym_ids
    |> Enum.flat_map(fn gid ->
      case FitTrackerz.Training.list_diet_templates_by_gym(gid, actor: actor) do
        {:ok, templates} -> templates
        _ -> []
      end
    end)
    |> Enum.filter(&(&1.created_by_id == actor.id))
  end

  defp difficulty_badge_class(level) do
    case level do
      :beginner -> "badge-success"
      :intermediate -> "badge-warning"
      :advanced -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp format_difficulty(level) do
    case level do
      :beginner -> "Beginner"
      :intermediate -> "Intermediate"
      :advanced -> "Advanced"
      _ -> "N/A"
    end
  end

  defp dietary_type_badge_class(type) do
    case type do
      :vegetarian -> "badge-success"
      :vegan -> "badge-primary"
      :eggetarian -> "badge-warning"
      :non_vegetarian -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp format_dietary_type(type) do
    case type do
      :vegetarian -> "Vegetarian"
      :non_vegetarian -> "Non-Vegetarian"
      :vegan -> "Vegan"
      :eggetarian -> "Eggetarian"
      _ -> "N/A"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Templates" subtitle="Reusable workout and diet plan templates." back_path="/trainer" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <.tab_group active="workouts" on_tab_change="change_tab">
          <:tab id="workouts" label="Workout Templates" icon="hero-fire-solid">
            <%!-- Workout Templates --%>
            <.section title="Workout Templates">
              <:actions>
                <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_workout_form" id="toggle-workout-template-btn">
                  New Template
                </.button>
              </:actions>

              <%!-- Workout Template Form --%>
              <%= if @show_workout_form do %>
                <div class="mb-6">
                  <.card title="New Workout Template">
                    <.form
                      for={@workout_form}
                      id="workout-template-form"
                      phx-change="validate_workout_template"
                      phx-submit="save_workout_template"
                      class="space-y-4"
                    >
                      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <.input
                          field={@workout_form[:name]}
                          label="Template Name"
                          placeholder="e.g., Push Pull Legs"
                          required
                        />
                        <div>
                          <label class="label">
                            <span class="label-text font-medium">Difficulty Level</span>
                          </label>
                          <select
                            name="workout_template[difficulty_level]"
                            class="select select-bordered w-full"
                            id="workout-template-difficulty-select"
                          >
                            <option value="">Select level...</option>
                            <option value="beginner">Beginner</option>
                            <option value="intermediate">Intermediate</option>
                            <option value="advanced">Advanced</option>
                          </select>
                        </div>
                        <div>
                          <label class="label"><span class="label-text font-medium">Gym</span></label>
                          <select
                            name="workout_template[gym_id]"
                            class="select select-bordered w-full"
                            id="workout-template-gym-select"
                            required
                          >
                            <option value="">Select a gym...</option>
                            <option :for={gym <- @gyms} value={gym.id}>
                              {gym.name}
                            </option>
                          </select>
                        </div>
                      </div>
                      <div class="flex justify-end gap-2 pt-2">
                        <.button type="button" variant="ghost" size="sm" phx-click="toggle_workout_form" id="cancel-workout-template-btn">
                          Cancel
                        </.button>
                        <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-workout-template-btn">
                          Create Template
                        </.button>
                      </div>
                    </.form>
                  </.card>
                </div>
              <% end %>

              <%= if @workout_templates == [] do %>
                <.empty_state
                  icon="hero-fire"
                  title="No workout templates yet"
                  subtitle="Create one to reuse across clients."
                >
                  <:action>
                    <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_workout_form">
                      Create Template
                    </.button>
                  </:action>
                </.empty_state>
              <% else %>
                <.data_table id="workout-templates-table" rows={@workout_templates} row_id={fn t -> "wt-#{t.id}" end}>
                  <:col :let={template} label="Name">
                    <span class="font-bold">{template.name}</span>
                  </:col>
                  <:col :let={template} label="Exercises">
                    <.badge variant="neutral">{length(template.exercises || [])} exercise(s)</.badge>
                  </:col>
                  <:col :let={template} label="Difficulty">
                    <%= if template.difficulty_level do %>
                      <span class={"badge badge-sm #{difficulty_badge_class(template.difficulty_level)}"}>
                        {format_difficulty(template.difficulty_level)}
                      </span>
                    <% else %>
                      <span class="text-base-content/40">--</span>
                    <% end %>
                  </:col>
                  <:actions :let={template}>
                    <.button
                      variant="danger"
                      size="sm"
                      icon="hero-trash"
                      phx-click="delete_workout_template"
                      phx-value-id={template.id}
                      data-confirm="Are you sure you want to delete this template?"
                      id={"delete-workout-template-#{template.id}"}
                    >
                      <span class="sr-only">Delete</span>
                    </.button>
                  </:actions>
                </.data_table>
              <% end %>
            </.section>
          </:tab>

          <:tab id="diets" label="Diet Templates" icon="hero-heart-solid">
            <%!-- Diet Templates --%>
            <.section title="Diet Templates">
              <:actions>
                <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_diet_form" id="toggle-diet-template-btn">
                  New Template
                </.button>
              </:actions>

              <%!-- Diet Template Form --%>
              <%= if @show_diet_form do %>
                <div class="mb-6">
                  <.card title="New Diet Template">
                    <.form
                      for={@diet_form}
                      id="diet-template-form"
                      phx-change="validate_diet_template"
                      phx-submit="save_diet_template"
                      class="space-y-4"
                    >
                      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        <.input
                          field={@diet_form[:name]}
                          label="Template Name"
                          placeholder="e.g., Keto Starter"
                          required
                        />
                        <.input
                          field={@diet_form[:calorie_target]}
                          label="Calorie Target"
                          type="number"
                          placeholder="2000"
                        />
                        <div>
                          <label class="label">
                            <span class="label-text font-medium">Dietary Type</span>
                          </label>
                          <select
                            name="diet_template[dietary_type]"
                            class="select select-bordered w-full"
                            id="diet-template-type-select"
                          >
                            <option value="">Select type...</option>
                            <option value="vegetarian">Vegetarian</option>
                            <option value="non_vegetarian">Non-Vegetarian</option>
                            <option value="vegan">Vegan</option>
                            <option value="eggetarian">Eggetarian</option>
                          </select>
                        </div>
                        <div>
                          <label class="label"><span class="label-text font-medium">Gym</span></label>
                          <select
                            name="diet_template[gym_id]"
                            class="select select-bordered w-full"
                            id="diet-template-gym-select"
                            required
                          >
                            <option value="">Select a gym...</option>
                            <option :for={gym <- @gyms} value={gym.id}>
                              {gym.name}
                            </option>
                          </select>
                        </div>
                      </div>
                      <div class="flex justify-end gap-2 pt-2">
                        <.button type="button" variant="ghost" size="sm" phx-click="toggle_diet_form" id="cancel-diet-template-btn">
                          Cancel
                        </.button>
                        <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-diet-template-btn">
                          Create Template
                        </.button>
                      </div>
                    </.form>
                  </.card>
                </div>
              <% end %>

              <%= if @diet_templates == [] do %>
                <.empty_state
                  icon="hero-heart"
                  title="No diet templates yet"
                  subtitle="Create one to reuse across clients."
                >
                  <:action>
                    <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_diet_form">
                      Create Template
                    </.button>
                  </:action>
                </.empty_state>
              <% else %>
                <.data_table id="diet-templates-table" rows={@diet_templates} row_id={fn t -> "dt-#{t.id}" end}>
                  <:col :let={template} label="Name">
                    <span class="font-bold">{template.name}</span>
                  </:col>
                  <:col :let={template} label="Calories">
                    {if template.calorie_target, do: "#{template.calorie_target} kcal/day", else: "--"}
                  </:col>
                  <:col :let={template} label="Type">
                    <%= if template.dietary_type do %>
                      <span class={"badge badge-sm #{dietary_type_badge_class(template.dietary_type)}"}>
                        {format_dietary_type(template.dietary_type)}
                      </span>
                    <% else %>
                      <span class="text-base-content/40">--</span>
                    <% end %>
                  </:col>
                  <:actions :let={template}>
                    <.button
                      variant="danger"
                      size="sm"
                      icon="hero-trash"
                      phx-click="delete_diet_template"
                      phx-value-id={template.id}
                      data-confirm="Are you sure you want to delete this template?"
                      id={"delete-diet-template-#{template.id}"}
                    >
                      <span class="sr-only">Delete</span>
                    </.button>
                  </:actions>
                </.data_table>
              <% end %>
            </.section>
          </:tab>
        </.tab_group>
      <% end %>
    </Layouts.app>
    """
  end
end
