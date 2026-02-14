defmodule FitconnexWeb.Member.DietLive do
  use FitconnexWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    uid = user.id

    memberships =
      Fitconnex.Gym.GymMember
      |> Ash.Query.filter(user_id == ^uid)
      |> Ash.Query.filter(is_active == true)
      |> Ash.Query.load([:gym, :assigned_trainer])
      |> Ash.read!()

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My Diet Plan",
           memberships: [],
           diet_plans: [],
           no_gym: true,
           plan_type: :general,
           show_form: false,
           form: nil,
           meals: []
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)

        diet_plans =
          Fitconnex.Training.DietPlan
          |> Ash.Query.filter(member_id in ^mids)
          |> Ash.Query.load([:gym, trainer: [:user]])
          |> Ash.read!()

        plan_type = determine_plan_type(mids)

        form =
          to_form(
            %{"name" => "", "calorie_target" => "", "dietary_type" => "", "gym_id" => ""},
            as: "diet"
          )

        {:ok,
         assign(socket,
           page_title: "My Diet Plan",
           memberships: memberships,
           diet_plans: diet_plans,
           no_gym: false,
           plan_type: plan_type,
           show_form: false,
           form: form,
           meals: [blank_meal(1)]
         )}
    end
  end

  defp determine_plan_type(member_ids) do
    active_sub =
      Fitconnex.Billing.MemberSubscription
      |> Ash.Query.filter(member_id in ^member_ids)
      |> Ash.Query.filter(status == :active)
      |> Ash.Query.load([:subscription_plan])
      |> Ash.read!()
      |> List.first()

    if active_sub && active_sub.subscription_plan,
      do: active_sub.subscription_plan.plan_type,
      else: :general
  end

  defp blank_meal(order) do
    %{
      "name" => "",
      "time_of_day" => "",
      "items" => "",
      "calories" => "",
      "protein" => "",
      "carbs" => "",
      "fat" => "",
      "order" => order
    }
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("validate", %{"diet" => params}, socket) do
    form = to_form(params, as: "diet")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("add_meal", _params, socket) do
    meals = socket.assigns.meals
    next_order = length(meals) + 1
    {:noreply, assign(socket, meals: meals ++ [blank_meal(next_order)])}
  end

  def handle_event("remove_meal", %{"index" => index}, socket) do
    idx = String.to_integer(index)
    meals = List.delete_at(socket.assigns.meals, idx)

    meals =
      meals
      |> Enum.with_index(1)
      |> Enum.map(fn {m, order} -> Map.put(m, "order", order) end)

    {:noreply, assign(socket, meals: meals)}
  end

  def handle_event("update_meal", %{"index" => index, "field" => field, "value" => value}, socket) do
    idx = String.to_integer(index)
    meals = List.update_at(socket.assigns.meals, idx, fn m -> Map.put(m, field, value) end)
    {:noreply, assign(socket, meals: meals)}
  end

  def handle_event("save_diet", %{"diet" => params}, socket) do
    memberships = socket.assigns.memberships
    membership = Enum.find(memberships, &(&1.gym_id == params["gym_id"])) || List.first(memberships)

    calorie_target =
      case Integer.parse(params["calorie_target"] || "") do
        {val, _} -> val
        :error -> nil
      end

    dietary_type =
      case params["dietary_type"] do
        "" -> nil
        nil -> nil
        val -> String.to_existing_atom(val)
      end

    meals =
      socket.assigns.meals
      |> Enum.map(fn m ->
        %{
          name: m["name"],
          time_of_day: m["time_of_day"],
          items: parse_items(m["items"]),
          calories: parse_int(m["calories"]),
          protein: parse_float(m["protein"]),
          carbs: parse_float(m["carbs"]),
          fat: parse_float(m["fat"]),
          order: m["order"]
        }
      end)
      |> Enum.reject(fn m -> m.name == "" or m.name == nil end)

    gym_id = if params["gym_id"] != "", do: params["gym_id"], else: membership.gym_id

    case Fitconnex.Training.DietPlan
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           calorie_target: calorie_target,
           dietary_type: dietary_type,
           meals: meals,
           member_id: membership.id,
           gym_id: gym_id
         })
         |> Ash.create() do
      {:ok, _plan} ->
        mids = Enum.map(memberships, & &1.id)

        diet_plans =
          Fitconnex.Training.DietPlan
          |> Ash.Query.filter(member_id in ^mids)
          |> Ash.Query.load([:gym, trainer: [:user]])
          |> Ash.read!()

        form =
          to_form(
            %{"name" => "", "calorie_target" => "", "dietary_type" => "", "gym_id" => ""},
            as: "diet"
          )

        {:noreply,
         socket
         |> assign(diet_plans: diet_plans, form: form, show_form: false, meals: [blank_meal(1)])
         |> put_flash(:info, "Diet plan created successfully.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create diet plan: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("delete_diet", %{"id" => id}, socket) do
    memberships = socket.assigns.memberships
    mids = Enum.map(memberships, & &1.id)

    diet =
      Fitconnex.Training.DietPlan
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(member_id in ^mids)
      |> Ash.Query.filter(is_nil(trainer_id))
      |> Ash.read!()
      |> List.first()

    if diet do
      Ash.destroy!(diet)

      diet_plans =
        Fitconnex.Training.DietPlan
        |> Ash.Query.filter(member_id in ^mids)
        |> Ash.Query.load([:gym, trainer: [:user]])
        |> Ash.read!()

      {:noreply,
       socket
       |> assign(diet_plans: diet_plans)
       |> put_flash(:info, "Diet plan deleted.")}
    else
      {:noreply, put_flash(socket, :error, "Diet plan not found.")}
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

  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_items(""), do: []
  defp parse_items(nil), do: []

  defp parse_items(val) when is_binary(val) do
    val
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp format_dietary_type(nil), do: "General"
  defp format_dietary_type(:vegetarian), do: "Vegetarian"
  defp format_dietary_type(:non_vegetarian), do: "Non-Vegetarian"
  defp format_dietary_type(:vegan), do: "Vegan"
  defp format_dietary_type(:eggetarian), do: "Eggetarian"
  defp format_dietary_type(other), do: other |> to_string() |> String.capitalize()

  defp dietary_badge_class(nil), do: "badge-ghost"
  defp dietary_badge_class(:vegetarian), do: "badge-success"
  defp dietary_badge_class(:vegan), do: "badge-accent"
  defp dietary_badge_class(:non_vegetarian), do: "badge-error"
  defp dietary_badge_class(:eggetarian), do: "badge-warning"
  defp dietary_badge_class(_), do: "badge-ghost"

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
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">My Diet Plans</h1>
              <p class="text-base-content/50 mt-1">
                <%= if @plan_type == :general do %>
                  Create and manage your own nutrition programs.
                <% else %>
                  View your personalized nutrition programs.
                <% end %>
              </p>
            </div>
          </div>
          <%= if @plan_type == :general and not @no_gym do %>
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
          <%!-- Create Form (General only) --%>
          <%= if @plan_type == :general and @show_form do %>
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
                  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
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
                      <label class="label"><span class="label-text font-medium">Dietary Type</span></label>
                      <select name="diet[dietary_type]" class="select select-bordered w-full" id="diet-type-select">
                        <option value="">Select type...</option>
                        <option value="vegetarian">Vegetarian</option>
                        <option value="non_vegetarian">Non-Vegetarian</option>
                        <option value="vegan">Vegan</option>
                        <option value="eggetarian">Eggetarian</option>
                      </select>
                    </div>
                    <div>
                      <label class="label"><span class="label-text font-medium">Gym</span></label>
                      <select name="diet[gym_id]" class="select select-bordered w-full" id="diet-gym-select" required>
                        <option value="">Select a gym...</option>
                        <option :for={m <- @memberships} value={m.gym_id}>
                          {m.gym.name}
                        </option>
                      </select>
                    </div>
                  </div>

                  <%!-- Meals --%>
                  <div class="space-y-3">
                    <div class="flex items-center justify-between">
                      <h3 class="font-semibold text-sm">Meals</h3>
                      <button type="button" class="btn btn-ghost btn-xs gap-1" phx-click="add_meal" id="add-meal-btn">
                        <.icon name="hero-plus-mini" class="size-3" /> Add Meal
                      </button>
                    </div>
                    <div
                      :for={{meal, idx} <- Enum.with_index(@meals)}
                      class="p-4 rounded-lg bg-base-300/20 space-y-3"
                      id={"meal-row-#{idx}"}
                    >
                      <div class="flex items-center justify-between">
                        <span class="text-xs font-semibold text-base-content/40 uppercase">
                          Meal #{idx + 1}
                        </span>
                        <%= if length(@meals) > 1 do %>
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs text-error"
                            phx-click="remove_meal"
                            phx-value-index={idx}
                            id={"remove-meal-#{idx}"}
                          >
                            <.icon name="hero-trash-mini" class="size-3" />
                          </button>
                        <% end %>
                      </div>
                      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <label class="label"><span class="label-text text-xs">Name</span></label>
                          <input
                            type="text"
                            value={meal["name"]}
                            placeholder="e.g., Breakfast"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="name"
                            id={"meal-name-#{idx}"}
                          />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Time</span></label>
                          <input
                            type="text"
                            value={meal["time_of_day"]}
                            placeholder="e.g., 8:00 AM"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="time_of_day"
                            id={"meal-time-#{idx}"}
                          />
                        </div>
                        <div class="col-span-2">
                          <label class="label"><span class="label-text text-xs">Items (comma-separated)</span></label>
                          <input
                            type="text"
                            value={meal["items"]}
                            placeholder="e.g., Oats, Banana, Milk"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="items"
                            id={"meal-items-#{idx}"}
                          />
                        </div>
                      </div>
                      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <label class="label"><span class="label-text text-xs">Calories</span></label>
                          <input
                            type="number"
                            value={meal["calories"]}
                            placeholder="500"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="calories"
                            id={"meal-calories-#{idx}"}
                          />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Protein (g)</span></label>
                          <input
                            type="number"
                            step="0.1"
                            value={meal["protein"]}
                            placeholder="30"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="protein"
                            id={"meal-protein-#{idx}"}
                          />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Carbs (g)</span></label>
                          <input
                            type="number"
                            step="0.1"
                            value={meal["carbs"]}
                            placeholder="50"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="carbs"
                            id={"meal-carbs-#{idx}"}
                          />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Fat (g)</span></label>
                          <input
                            type="number"
                            step="0.1"
                            value={meal["fat"]}
                            placeholder="15"
                            class="input input-bordered input-sm w-full"
                            phx-blur="update_meal"
                            phx-value-index={idx}
                            phx-value-field="fat"
                            id={"meal-fat-#{idx}"}
                          />
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="flex justify-end gap-2 pt-2">
                    <button type="button" class="btn btn-ghost btn-sm" phx-click="toggle_form" id="cancel-diet-btn">
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

          <%= if @diet_plans == [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-diet-plans">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-success/10 flex items-center justify-center mb-4">
                  <.icon name="hero-heart" class="size-8 text-success" />
                </div>
                <h2 class="text-lg font-bold">No Diet Plans Yet</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  <%= if @plan_type == :general do %>
                    Create your first diet plan to start your nutrition journey!
                  <% else %>
                    Your trainer will create a nutrition plan based on your goals. Check back soon!
                  <% end %>
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Diet Plan Cards --%>
            <div class="space-y-6">
              <div
                :for={plan <- @diet_plans}
                class="card bg-base-200/50 border border-base-300/50"
                id={"diet-plan-#{plan.id}"}
              >
                <div class="card-body p-5">
                  <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                    <div>
                      <h2 class="text-lg font-bold flex items-center gap-2">
                        <.icon name="hero-heart-solid" class="size-5 text-success" />
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
                            <.icon name="hero-academic-cap-mini" class="size-3" />
                            Assigned by {plan.trainer.user.name}
                          </span>
                        <% else %>
                          <span class="badge badge-ghost badge-xs">Self-created</span>
                        <% end %>
                      </div>
                    </div>
                    <div class="flex flex-wrap items-center gap-2">
                      <span class={"badge badge-sm #{dietary_badge_class(plan.dietary_type)}"}>
                        {format_dietary_type(plan.dietary_type)}
                      </span>
                      <%= if plan.calorie_target do %>
                        <span class="badge badge-warning badge-outline badge-sm">
                          {plan.calorie_target} kcal/day
                        </span>
                      <% end %>
                      <%= if @plan_type == :general and is_nil(plan.trainer_id) do %>
                        <button
                          class="btn btn-ghost btn-xs text-error"
                          phx-click="delete_diet"
                          phx-value-id={plan.id}
                          data-confirm="Are you sure you want to delete this diet plan?"
                          id={"delete-diet-#{plan.id}"}
                        >
                          <.icon name="hero-trash-mini" class="size-4" />
                        </button>
                      <% end %>
                    </div>
                  </div>

                  <%!-- Meals --%>
                  <div class="mt-5 space-y-3">
                    <div
                      :for={meal <- Enum.sort_by(plan.meals || [], & &1.order)}
                      class="p-4 rounded-xl bg-base-300/20"
                      id={"meal-#{plan.id}-#{meal.order}"}
                    >
                      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                        <div class="flex items-center gap-3">
                          <div class="w-8 h-8 rounded-lg bg-success/10 flex items-center justify-center shrink-0">
                            <span class="text-xs font-bold text-success">{meal.order}</span>
                          </div>
                          <div>
                            <p class="text-sm font-semibold">{meal.name}</p>
                            <p class="text-xs text-base-content/40">{meal.time_of_day}</p>
                          </div>
                        </div>
                        <div class="flex flex-wrap items-center gap-3 text-xs">
                          <%= if meal.calories do %>
                            <span class="flex items-center gap-1 text-warning font-medium">
                              <.icon name="hero-fire-mini" class="size-3" />
                              {meal.calories} cal
                            </span>
                          <% end %>
                          <%= if meal.protein do %>
                            <span class="text-info font-medium">P: {Float.round(meal.protein, 1)}g</span>
                          <% end %>
                          <%= if meal.carbs do %>
                            <span class="text-accent font-medium">C: {Float.round(meal.carbs, 1)}g</span>
                          <% end %>
                          <%= if meal.fat do %>
                            <span class="text-error font-medium">F: {Float.round(meal.fat, 1)}g</span>
                          <% end %>
                        </div>
                      </div>
                      <%= if meal.items != [] do %>
                        <div class="mt-3 flex flex-wrap gap-1.5">
                          <span :for={item <- meal.items} class="badge badge-ghost badge-sm">
                            {item}
                          </span>
                        </div>
                      <% end %>
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
