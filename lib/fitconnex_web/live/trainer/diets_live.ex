defmodule FitconnexWeb.Trainer.DietsLive do
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
       |> assign(page_title: "Diet Plans")
       |> assign(no_gym: true, diets: [], clients: [], gyms: [], form: nil, show_form: false)}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)

      diets =
        Fitconnex.Training.DietPlan
        |> Ash.Query.filter(trainer_id == ^uid)
        |> Ash.Query.load([:member, :gym])
        |> Ash.read!()

      clients =
        Fitconnex.Gym.GymMember
        |> Ash.Query.filter(assigned_trainer_id == ^uid)
        |> Ash.Query.load([:user])
        |> Ash.read!()

      form =
        to_form(
          %{
            "name" => "",
            "calorie_target" => "",
            "dietary_type" => "",
            "member_id" => "",
            "gym_id" => ""
          },
          as: "diet"
        )

      {:ok,
       socket
       |> assign(page_title: "Diet Plans")
       |> assign(
         no_gym: false,
         diets: diets,
         clients: clients,
         gyms: gyms,
         form: form,
         show_form: false
       )}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("validate", %{"diet" => params}, socket) do
    form = to_form(params, as: "diet")
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save_diet", %{"diet" => params}, socket) do
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

    case Fitconnex.Training.DietPlan
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           calorie_target: calorie_target,
           dietary_type: dietary_type,
           member_id: params["member_id"],
           gym_id: params["gym_id"],
           trainer_id: uid
         })
         |> Ash.create() do
      {:ok, _plan} ->
        diets =
          Fitconnex.Training.DietPlan
          |> Ash.Query.filter(trainer_id == ^uid)
          |> Ash.Query.load([:member, :gym])
          |> Ash.read!()

        form =
          to_form(
            %{
              "name" => "",
              "calorie_target" => "",
              "dietary_type" => "",
              "member_id" => "",
              "gym_id" => ""
            },
            as: "diet"
          )

        {:noreply,
         socket
         |> assign(diets: diets, form: form, show_form: false)
         |> put_flash(:info, "Diet plan created successfully.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create diet plan: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_diet", %{"id" => id}, socket) do
    uid = socket.assigns.current_user.id

    diet =
      Fitconnex.Training.DietPlan
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(trainer_id == ^uid)
      |> Ash.read!()
      |> List.first()

    if diet do
      Ash.destroy!(diet)

      diets =
        Fitconnex.Training.DietPlan
        |> Ash.Query.filter(trainer_id == ^uid)
        |> Ash.Query.load([:member, :gym])
        |> Ash.read!()

      {:noreply,
       socket
       |> assign(diets: diets)
       |> put_flash(:info, "Diet plan deleted.")}
    else
      {:noreply, put_flash(socket, :error, "Diet plan not found.")}
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
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Diet Plans</h1>
              <p class="text-base-content/50 mt-1">Create and manage diet plans for your clients.</p>
            </div>
          </div>
          <%= unless @no_gym do %>
            <button
              class="btn btn-primary btn-sm gap-2 font-semibold"
              phx-click="toggle_form"
              id="toggle-diet-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> New Diet Plan
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
            <div class="card bg-base-200/50 border border-base-300/50" id="diet-form-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-heart-solid" class="size-5 text-success" /> New Diet Plan
                </h2>
                <.form
                  for={@form}
                  id="diet-form"
                  phx-change="validate"
                  phx-submit="save_diet"
                  class="mt-4 space-y-4"
                >
                  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    <.input
                      field={@form[:name]}
                      label="Plan Name"
                      placeholder="e.g., High Protein Plan"
                      required
                    />
                    <.input
                      field={@form[:calorie_target]}
                      label="Calorie Target"
                      type="number"
                      placeholder="2000"
                    />
                    <div>
                      <label class="label">
                        <span class="label-text font-medium">Dietary Type</span>
                      </label>
                      <select
                        name="diet[dietary_type]"
                        class="select select-bordered w-full"
                        id="diet-type-select"
                      >
                        <option value="">Select type...</option>
                        <option value="vegetarian">Vegetarian</option>
                        <option value="non_vegetarian">Non-Vegetarian</option>
                        <option value="vegan">Vegan</option>
                        <option value="eggetarian">Eggetarian</option>
                      </select>
                    </div>
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label class="label"><span class="label-text font-medium">Client</span></label>
                      <select
                        name="diet[member_id]"
                        class="select select-bordered w-full"
                        id="diet-member-select"
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
                        name="diet[gym_id]"
                        class="select select-bordered w-full"
                        id="diet-gym-select"
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
                      phx-click="toggle_form"
                      id="cancel-diet-btn"
                    >
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="submit-diet-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Create Plan
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Diet Plans Grid --%>
          <%= if @diets == [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="diets-empty">
              <div class="card-body p-8 items-center text-center">
                <div class="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mb-4">
                  <.icon name="hero-heart-solid" class="size-8 text-success" />
                </div>
                <h2 class="text-lg font-bold">No Diet Plans Yet</h2>
                <p class="text-base-content/50 mt-2 max-w-md">
                  Create your first diet plan to help your clients with their nutrition.
                </p>
              </div>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="diets-grid">
              <div
                :for={diet <- @diets}
                class="card bg-base-200/50 border border-base-300/50"
                id={"diet-card-#{diet.id}"}
              >
                <div class="card-body p-5">
                  <div class="flex items-start justify-between">
                    <h3 class="font-bold text-md">{diet.name}</h3>
                    <button
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="delete_diet"
                      phx-value-id={diet.id}
                      data-confirm="Are you sure you want to delete this diet plan?"
                      id={"delete-diet-#{diet.id}"}
                    >
                      <.icon name="hero-trash-mini" class="size-4" />
                    </button>
                  </div>
                  <div class="space-y-2 mt-2">
                    <div class="flex items-center gap-2 text-sm text-base-content/60">
                      <.icon name="hero-user-mini" class="size-4" />
                      <span>{if diet.member, do: diet.member.id, else: "Unassigned"}</span>
                    </div>
                    <div class="flex items-center gap-2 text-sm text-base-content/60">
                      <.icon name="hero-building-office-2-mini" class="size-4" />
                      <span>{if diet.gym, do: diet.gym.name, else: "N/A"}</span>
                    </div>
                    <%= if diet.calorie_target do %>
                      <div class="flex items-center gap-2 text-sm text-base-content/60">
                        <.icon name="hero-fire-mini" class="size-4" />
                        <span>{diet.calorie_target} kcal/day</span>
                      </div>
                    <% end %>
                    <%= if diet.dietary_type do %>
                      <div class="mt-2">
                        <span class={"badge badge-sm #{dietary_type_badge_class(diet.dietary_type)}"}>
                          {format_dietary_type(diet.dietary_type)}
                        </span>
                      </div>
                    <% end %>
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
