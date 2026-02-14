defmodule FitconnexWeb.Trainer.TemplatesLive do
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

      workout_templates =
        Fitconnex.Training.WorkoutPlanTemplate
        |> Ash.Query.filter(created_by_id == ^uid)
        |> Ash.read!()

      diet_templates =
        Fitconnex.Training.DietPlanTemplate
        |> Ash.Query.filter(created_by_id == ^uid)
        |> Ash.read!()

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
    user = socket.assigns.current_user
    uid = user.id

    difficulty_level =
      case params["difficulty_level"] do
        "" -> nil
        val -> String.to_existing_atom(val)
      end

    case Fitconnex.Training.WorkoutPlanTemplate
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           difficulty_level: difficulty_level,
           gym_id: params["gym_id"],
           created_by_id: uid
         })
         |> Ash.create() do
      {:ok, _template} ->
        workout_templates =
          Fitconnex.Training.WorkoutPlanTemplate
          |> Ash.Query.filter(created_by_id == ^uid)
          |> Ash.read!()

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

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create workout template: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("save_diet_template", %{"diet_template" => params}, socket) do
    user = socket.assigns.current_user
    uid = user.id

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

    case Fitconnex.Training.DietPlanTemplate
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           calorie_target: calorie_target,
           dietary_type: dietary_type,
           gym_id: params["gym_id"],
           created_by_id: uid
         })
         |> Ash.create() do
      {:ok, _template} ->
        diet_templates =
          Fitconnex.Training.DietPlanTemplate
          |> Ash.Query.filter(created_by_id == ^uid)
          |> Ash.read!()

        diet_form =
          to_form(%{"name" => "", "calorie_target" => "", "dietary_type" => "", "gym_id" => ""},
            as: "diet_template"
          )

        {:noreply,
         socket
         |> assign(diet_templates: diet_templates, diet_form: diet_form, show_diet_form: false)
         |> put_flash(:info, "Diet template created successfully.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create diet template: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_workout_template", %{"id" => id}, socket) do
    uid = socket.assigns.current_user.id

    template =
      Fitconnex.Training.WorkoutPlanTemplate
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(created_by_id == ^uid)
      |> Ash.read!()
      |> List.first()

    if template do
      case Ash.destroy(template) do
        :ok ->
          workout_templates =
            Fitconnex.Training.WorkoutPlanTemplate
            |> Ash.Query.filter(created_by_id == ^uid)
            |> Ash.read!()

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
    uid = socket.assigns.current_user.id

    template =
      Fitconnex.Training.DietPlanTemplate
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(created_by_id == ^uid)
      |> Ash.read!()
      |> List.first()

    if template do
      case Ash.destroy(template) do
        :ok ->
          diet_templates =
            Fitconnex.Training.DietPlanTemplate
            |> Ash.Query.filter(created_by_id == ^uid)
            |> Ash.read!()

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
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Templates</h1>
              <p class="text-base-content/50 mt-1">Reusable workout and diet plan templates.</p>
            </div>
          </div>
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
          <%!-- Workout Templates Section --%>
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-bold flex items-center gap-2">
                <.icon name="hero-fire-solid" class="size-5 text-accent" /> Workout Templates
              </h2>
              <button
                class="btn btn-primary btn-sm gap-2 font-semibold"
                phx-click="toggle_workout_form"
                id="toggle-workout-template-btn"
              >
                <.icon name="hero-plus-mini" class="size-4" /> New Template
              </button>
            </div>

            <%!-- Workout Template Form --%>
            <%= if @show_workout_form do %>
              <div
                class="card bg-base-200/50 border border-base-300/50"
                id="workout-template-form-card"
              >
                <div class="card-body p-5">
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
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        phx-click="toggle_workout_form"
                        id="cancel-workout-template-btn"
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm gap-2"
                        id="submit-workout-template-btn"
                      >
                        <.icon name="hero-check-mini" class="size-4" /> Create Template
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            <% end %>

            <%!-- Workout Templates List --%>
            <%= if @workout_templates == [] do %>
              <div class="card bg-base-200/50 border border-base-300/50" id="workout-templates-empty">
                <div class="card-body p-6 items-center text-center">
                  <div class="w-12 h-12 rounded-full bg-accent/10 flex items-center justify-center mb-3">
                    <.icon name="hero-fire-solid" class="size-6 text-accent" />
                  </div>
                  <p class="text-base-content/50 text-sm">
                    No workout templates yet. Create one to reuse across clients.
                  </p>
                </div>
              </div>
            <% else %>
              <div
                class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
                id="workout-templates-grid"
              >
                <div
                  :for={template <- @workout_templates}
                  class="card bg-base-200/50 border border-base-300/50"
                  id={"workout-template-#{template.id}"}
                >
                  <div class="card-body p-5">
                    <div class="flex items-start justify-between">
                      <h3 class="font-bold text-md">{template.name}</h3>
                      <button
                        class="btn btn-ghost btn-xs text-error"
                        phx-click="delete_workout_template"
                        phx-value-id={template.id}
                        data-confirm="Are you sure you want to delete this template?"
                        id={"delete-workout-template-#{template.id}"}
                      >
                        <.icon name="hero-trash-mini" class="size-4" />
                      </button>
                    </div>
                    <div class="space-y-2 mt-2">
                      <div class="flex items-center gap-2 text-sm text-base-content/60">
                        <.icon name="hero-list-bullet-mini" class="size-4" />
                        <span>{length(template.exercises || [])} exercise(s)</span>
                      </div>
                      <%= if template.difficulty_level do %>
                        <div class="mt-2">
                          <span class={"badge badge-sm #{difficulty_badge_class(template.difficulty_level)}"}>
                            {format_difficulty(template.difficulty_level)}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="divider"></div>

          <%!-- Diet Templates Section --%>
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-bold flex items-center gap-2">
                <.icon name="hero-heart-solid" class="size-5 text-success" /> Diet Templates
              </h2>
              <button
                class="btn btn-success btn-sm gap-2 font-semibold"
                phx-click="toggle_diet_form"
                id="toggle-diet-template-btn"
              >
                <.icon name="hero-plus-mini" class="size-4" /> New Template
              </button>
            </div>

            <%!-- Diet Template Form --%>
            <%= if @show_diet_form do %>
              <div class="card bg-base-200/50 border border-base-300/50" id="diet-template-form-card">
                <div class="card-body p-5">
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
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        phx-click="toggle_diet_form"
                        id="cancel-diet-template-btn"
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm gap-2"
                        id="submit-diet-template-btn"
                      >
                        <.icon name="hero-check-mini" class="size-4" /> Create Template
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            <% end %>

            <%!-- Diet Templates List --%>
            <%= if @diet_templates == [] do %>
              <div class="card bg-base-200/50 border border-base-300/50" id="diet-templates-empty">
                <div class="card-body p-6 items-center text-center">
                  <div class="w-12 h-12 rounded-full bg-success/10 flex items-center justify-center mb-3">
                    <.icon name="hero-heart-solid" class="size-6 text-success" />
                  </div>
                  <p class="text-base-content/50 text-sm">
                    No diet templates yet. Create one to reuse across clients.
                  </p>
                </div>
              </div>
            <% else %>
              <div
                class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
                id="diet-templates-grid"
              >
                <div
                  :for={template <- @diet_templates}
                  class="card bg-base-200/50 border border-base-300/50"
                  id={"diet-template-#{template.id}"}
                >
                  <div class="card-body p-5">
                    <div class="flex items-start justify-between">
                      <h3 class="font-bold text-md">{template.name}</h3>
                      <button
                        class="btn btn-ghost btn-xs text-error"
                        phx-click="delete_diet_template"
                        phx-value-id={template.id}
                        data-confirm="Are you sure you want to delete this template?"
                        id={"delete-diet-template-#{template.id}"}
                      >
                        <.icon name="hero-trash-mini" class="size-4" />
                      </button>
                    </div>
                    <div class="space-y-2 mt-2">
                      <%= if template.calorie_target do %>
                        <div class="flex items-center gap-2 text-sm text-base-content/60">
                          <.icon name="hero-fire-mini" class="size-4" />
                          <span>{template.calorie_target} kcal/day</span>
                        </div>
                      <% end %>
                      <%= if template.dietary_type do %>
                        <div class="mt-2">
                          <span class={"badge badge-sm #{dietary_type_badge_class(template.dietary_type)}"}>
                            {format_dietary_type(template.dietary_type)}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
