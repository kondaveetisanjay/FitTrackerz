defmodule FitTrackerzWeb.Trainer.DietsLive do
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
       |> assign(page_title: "Diet Plans")
       |> assign(no_gym: true, diets: [], clients: [], gyms: [], gym_trainers: [], form: nil, show_form: false, meals: [], editing_diet_id: nil, viewing_diet_id: nil)}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
        {:ok, diets} -> diets
        _ -> []
      end

      clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user]) do
        {:ok, members} -> members
        _ -> []
      end

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
         gym_trainers: gym_trainers,
         form: form,
         show_form: false,
         meals: [blank_meal(1)],
         editing_diet_id: nil,
         viewing_diet_id: nil
       )}
    end
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
    show = !socket.assigns.show_form

    socket =
      if show do
        form =
          to_form(
            %{"name" => "", "calorie_target" => "", "dietary_type" => "", "member_id" => "", "gym_id" => ""},
            as: "diet"
          )

        assign(socket,
          show_form: true,
          editing_diet_id: nil,
          form: form,
          meals: [blank_meal(1)]
        )
      else
        assign(socket, show_form: false, editing_diet_id: nil)
      end

    {:noreply, socket}
  end

  def handle_event("view_diet", %{"id" => id}, socket) do
    {:noreply, assign(socket, viewing_diet_id: id)}
  end

  def handle_event("close_view", _params, socket) do
    {:noreply, assign(socket, viewing_diet_id: nil)}
  end

  def handle_event("edit_diet", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.diets, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Diet plan not found.")}

      diet ->
        form =
          to_form(
            %{
              "name" => diet.name || "",
              "calorie_target" => to_string(diet.calorie_target || ""),
              "dietary_type" => to_string(diet.dietary_type || ""),
              "member_id" => diet.member_id || "",
              "gym_id" => diet.gym_id || ""
            },
            as: "diet"
          )

        meals =
          (diet.meals || [])
          |> Enum.sort_by(& &1.order)
          |> Enum.with_index(1)
          |> Enum.map(fn {m, order} ->
            %{
              "name" => m.name || "",
              "time_of_day" => m.time_of_day || "",
              "items" => Enum.join(m.items || [], ", "),
              "calories" => to_string(m.calories || ""),
              "protein" => to_string(m.protein || ""),
              "carbs" => to_string(m.carbs || ""),
              "fat" => to_string(m.fat || ""),
              "order" => order
            }
          end)

        meals = if meals == [], do: [blank_meal(1)], else: meals

        {:noreply,
         assign(socket,
           show_form: true,
           editing_diet_id: diet.id,
           viewing_diet_id: nil,
           form: form,
           meals: meals
         )}
    end
  end

  @impl true
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
    idx = parse_index(index)
    meals = List.delete_at(socket.assigns.meals, idx)

    meals =
      meals
      |> Enum.with_index(1)
      |> Enum.map(fn {m, order} -> Map.put(m, "order", order) end)

    {:noreply, assign(socket, meals: meals)}
  end

  def handle_event("update_meal", %{"index" => index, "field" => field, "value" => value}, socket) do
    idx = parse_index(index)
    meals = List.update_at(socket.assigns.meals, idx, fn m -> Map.put(m, field, value) end)
    {:noreply, assign(socket, meals: meals)}
  end

  @impl true
  def handle_event("save_diet", %{"diet" => params}, socket) do
    gym_trainers = socket.assigns.gym_trainers
    trainer_ids = Enum.map(gym_trainers, & &1.id)
    gym_trainer = Enum.find(gym_trainers, &(&1.gym_id == params["gym_id"]))

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

    actor = socket.assigns.current_user

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

    result =
      case socket.assigns.editing_diet_id do
        nil ->
          FitTrackerz.Training.create_diet(
            %{
              name: params["name"],
              calorie_target: calorie_target,
              dietary_type: dietary_type,
              meals: meals,
              member_id: params["member_id"],
              gym_id: params["gym_id"],
              trainer_id: gym_trainer && gym_trainer.id
            },
            actor: actor
          )

        id ->
          case Enum.find(socket.assigns.diets, &(&1.id == id)) do
            nil ->
              {:error, "Diet plan not found."}

            diet ->
              FitTrackerz.Training.update_diet(
                diet,
                %{
                  name: params["name"],
                  calorie_target: calorie_target,
                  dietary_type: dietary_type,
                  meals: meals
                },
                actor: actor
              )
          end
      end

    case result do
      {:ok, _plan} ->
        diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
          {:ok, diets} -> diets
          _ -> []
        end

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

        flash_msg =
          if socket.assigns.editing_diet_id,
            do: "Diet plan updated successfully.",
            else: "Diet plan created successfully."

        {:noreply,
         socket
         |> assign(
           diets: diets,
           form: form,
           show_form: false,
           meals: [blank_meal(1)],
           editing_diet_id: nil
         )
         |> put_flash(:info, flash_msg)}

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

  @impl true
  def handle_event("delete_diet", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    trainer_ids = Enum.map(socket.assigns.gym_trainers, & &1.id)
    diet = Enum.find(socket.assigns.diets, &(&1.id == id))

    if diet do
      case FitTrackerz.Training.destroy_diet(diet, actor: actor) do
        :ok ->
          diets = case FitTrackerz.Training.list_diets_by_trainer(trainer_ids, actor: actor, load: [:gym, member: [:user]]) do
            {:ok, diets} -> diets
            _ -> []
          end

          {:noreply,
           socket
           |> assign(diets: diets)
           |> put_flash(:info, "Diet plan deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete diet plan.")}
      end
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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Diet Plans" subtitle="Create and manage diet plans for your clients." back_path="/trainer/dashboard">
        <:actions>
          <%= unless @no_gym do %>
            <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form" id="toggle-diet-form-btn">
              New Diet Plan
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
        <%!-- View / Detail Card --%>
        <% viewing_diet = if @viewing_diet_id, do: Enum.find(@diets, &(&1.id == @viewing_diet_id)) %>
        <%= if viewing_diet do %>
          <% diet = viewing_diet %>
          <div class="mb-8">
            <.card id={"diet-detail-#{diet.id}"}>
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                <div>
                  <h2 class="text-lg font-bold flex items-center gap-2">
                    <.icon name="hero-heart-solid" class="size-5 text-success" />
                    {diet.name}
                  </h2>
                  <div class="flex flex-wrap items-center gap-3 mt-2 text-xs text-base-content/50">
                    <%= if diet.member do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-user-mini" class="size-3" />
                        {diet.member.user.name}
                      </span>
                    <% end %>
                    <%= if diet.gym do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-building-office-2-mini" class="size-3" />
                        {diet.gym.name}
                      </span>
                    <% end %>
                  </div>
                </div>
                <div class="flex flex-wrap items-center gap-2">
                  <%= if diet.dietary_type do %>
                    <span class={"badge #{dietary_type_badge_class(diet.dietary_type)}"}>
                      {format_dietary_type(diet.dietary_type)}
                    </span>
                  <% end %>
                  <%= if diet.calorie_target do %>
                    <span class="badge badge-warning">{diet.calorie_target} kcal/day</span>
                  <% end %>
                  <.button variant="ghost" size="sm" icon="hero-pencil-square" phx-click="edit_diet" phx-value-id={diet.id} id={"edit-detail-#{diet.id}"}>
                    Edit
                  </.button>
                  <.button variant="ghost" size="sm" icon="hero-x-mark" phx-click="close_view" id={"close-detail-#{diet.id}"}>
                    Close
                  </.button>
                </div>
              </div>

              <div class="mt-5 space-y-3">
                <%= if (diet.meals || []) == [] do %>
                  <p class="text-sm text-base-content/50">No meals added to this plan.</p>
                <% else %>
                  <div
                    :for={meal <- Enum.sort_by(diet.meals || [], & &1.order)}
                    class="p-4 rounded-xl bg-base-300/20"
                    id={"detail-meal-#{diet.id}-#{meal.order}"}
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
                          <span class="text-info font-medium">P: {Float.round(meal.protein * 1.0, 1)}g</span>
                        <% end %>
                        <%= if meal.carbs do %>
                          <span class="text-accent font-medium">C: {Float.round(meal.carbs * 1.0, 1)}g</span>
                        <% end %>
                        <%= if meal.fat do %>
                          <span class="text-error font-medium">F: {Float.round(meal.fat * 1.0, 1)}g</span>
                        <% end %>
                      </div>
                    </div>
                    <%= if (meal.items || []) != [] do %>
                      <div class="mt-3 flex flex-wrap gap-1.5">
                        <span :for={item <- meal.items} class="badge badge-neutral badge-sm">{item}</span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </.card>
          </div>
        <% end %>

        <%!-- Create/Edit Form --%>
        <%= if @show_form do %>
          <div class="mb-8">
            <.card title={if @editing_diet_id, do: "Edit Diet Plan", else: "New Diet Plan"}>
              <.form
                for={@form}
                id="diet-form"
                phx-change="validate"
                phx-submit="save_diet"
                class="space-y-4"
              >
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div>
                    <label class="label"><span class="label-text font-medium">Plan Name</span></label>
                    <input
                      type="text"
                      name="diet[name]"
                      id="diet_name"
                      value={@form[:name].value || ""}
                      placeholder="e.g., High Protein Plan"
                      class="w-full input"
                    />
                  </div>
                  <div>
                    <label class="label"><span class="label-text font-medium">Calorie Target</span></label>
                    <input
                      type="number"
                      name="diet[calorie_target]"
                      id="diet_calorie_target"
                      value={@form[:calorie_target].value || ""}
                      placeholder="2000"
                      class="w-full input"
                    />
                  </div>
                  <div>
                    <label class="label">
                      <span class="label-text font-medium">Dietary Type</span>
                    </label>
                    <select
                      name="diet[dietary_type]"
                      class="select select-bordered w-full"
                      id="diet-type-select"
                    >
                      <option value="" selected={@form[:dietary_type].value in [nil, ""]}>Select type...</option>
                      <option value="vegetarian" selected={to_string(@form[:dietary_type].value) == "vegetarian"}>Vegetarian</option>
                      <option value="non_vegetarian" selected={to_string(@form[:dietary_type].value) == "non_vegetarian"}>Non-Vegetarian</option>
                      <option value="vegan" selected={to_string(@form[:dietary_type].value) == "vegan"}>Vegan</option>
                      <option value="eggetarian" selected={to_string(@form[:dietary_type].value) == "eggetarian"}>Eggetarian</option>
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
                      disabled={@editing_diet_id != nil}
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
                    <%= if @editing_diet_id do %>
                      <input type="hidden" name="diet[member_id]" value={@form[:member_id].value || ""} />
                    <% end %>
                  </div>
                  <div>
                    <label class="label"><span class="label-text font-medium">Gym</span></label>
                    <select
                      name="diet[gym_id]"
                      class="select select-bordered w-full"
                      id="diet-gym-select"
                      disabled={@editing_diet_id != nil}
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
                    <%= if @editing_diet_id do %>
                      <input type="hidden" name="diet[gym_id]" value={@form[:gym_id].value || ""} />
                    <% end %>
                  </div>
                </div>
                <%!-- Meals --%>
                <.section title="Meals">
                  <:actions>
                    <.button variant="ghost" size="sm" icon="hero-plus" type="button" phx-click="add_meal" id="add-meal-btn">
                      Add Meal
                    </.button>
                  </:actions>
                  <div class="space-y-3">
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
                          <.button variant="ghost" size="sm" type="button" phx-click="remove_meal" phx-value-index={idx} id={"remove-meal-#{idx}"} class="text-error">
                            <.icon name="hero-trash-mini" class="size-3" />
                          </.button>
                        <% end %>
                      </div>
                      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <label class="label"><span class="label-text text-xs">Name</span></label>
                          <input type="text" value={meal["name"]} placeholder="e.g., Breakfast" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="name" id={"meal-name-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Time</span></label>
                          <input type="text" value={meal["time_of_day"]} placeholder="e.g., 8:00 AM" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="time_of_day" id={"meal-time-#{idx}"} />
                        </div>
                        <div class="col-span-2">
                          <label class="label"><span class="label-text text-xs">Items (comma-separated)</span></label>
                          <input type="text" value={meal["items"]} placeholder="e.g., Oats, Banana, Milk" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="items" id={"meal-items-#{idx}"} />
                        </div>
                      </div>
                      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <label class="label"><span class="label-text text-xs">Calories</span></label>
                          <input type="number" value={meal["calories"]} placeholder="500" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="calories" id={"meal-calories-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Protein (g)</span></label>
                          <input type="number" step="0.1" value={meal["protein"]} placeholder="30" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="protein" id={"meal-protein-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Carbs (g)</span></label>
                          <input type="number" step="0.1" value={meal["carbs"]} placeholder="50" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="carbs" id={"meal-carbs-#{idx}"} />
                        </div>
                        <div>
                          <label class="label"><span class="label-text text-xs">Fat (g)</span></label>
                          <input type="number" step="0.1" value={meal["fat"]} placeholder="15" class="input input-bordered input-sm w-full" phx-blur="update_meal" phx-value-index={idx} phx-value-field="fat" id={"meal-fat-#{idx}"} />
                        </div>
                      </div>
                    </div>
                  </div>
                </.section>

                <div class="flex justify-end gap-2 pt-2">
                  <.button type="button" variant="ghost" size="sm" phx-click="toggle_form" id="cancel-diet-btn">
                    Cancel
                  </.button>
                  <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-diet-btn">
                    {if @editing_diet_id, do: "Update Plan", else: "Create Plan"}
                  </.button>
                </div>
              </.form>
            </.card>
          </div>
        <% end %>

        <%!-- Diet Plans --%>
        <%= if @diets == [] do %>
          <.empty_state
            icon="hero-heart"
            title="No Diet Plans Yet"
            subtitle="Create your first diet plan to help your clients with their nutrition."
          >
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form">
                Create Diet Plan
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <.data_table id="diets-table" rows={@diets} row_id={fn d -> "diet-#{d.id}" end}>
            <:col :let={diet} label="Plan Name">
              <button type="button" phx-click="view_diet" phx-value-id={diet.id} class="font-bold text-left hover:text-primary transition-colors">
                {diet.name}
              </button>
            </:col>
            <:col :let={diet} label="Client">
              <div class="flex items-center gap-2">
                <%= if diet.member do %>
                  <.avatar name={diet.member.user.name} size="sm" />
                  <span>{diet.member.user.name}</span>
                <% else %>
                  <span class="text-base-content/40">Unassigned</span>
                <% end %>
              </div>
            </:col>
            <:col :let={diet} label="Gym">
              {if diet.gym, do: diet.gym.name, else: "N/A"}
            </:col>
            <:col :let={diet} label="Calories">
              {if diet.calorie_target, do: "#{diet.calorie_target} kcal", else: "--"}
            </:col>
            <:col :let={diet} label="Type">
              <%= if diet.dietary_type do %>
                <span class={"badge badge-sm #{dietary_type_badge_class(diet.dietary_type)}"}>
                  {format_dietary_type(diet.dietary_type)}
                </span>
              <% else %>
                <span class="text-base-content/40">--</span>
              <% end %>
            </:col>
            <:actions :let={diet}>
              <div class="flex gap-1">
                <.button
                  variant="ghost"
                  size="sm"
                  icon="hero-eye"
                  phx-click="view_diet"
                  phx-value-id={diet.id}
                  id={"view-diet-#{diet.id}"}
                >
                  <span class="sr-only">View</span>
                </.button>
                <.button
                  variant="ghost"
                  size="sm"
                  icon="hero-pencil-square"
                  phx-click="edit_diet"
                  phx-value-id={diet.id}
                  id={"edit-diet-#{diet.id}"}
                >
                  <span class="sr-only">Edit</span>
                </.button>
                <.button
                  variant="danger"
                  size="sm"
                  icon="hero-trash"
                  phx-click="delete_diet"
                  phx-value-id={diet.id}
                  data-confirm="Are you sure you want to delete this diet plan?"
                >
                  <span class="sr-only">Delete</span>
                </.button>
              </div>
            </:actions>
            <:mobile_card :let={diet}>
              <div>
                <p class="font-bold">{diet.name}</p>
                <p class="text-xs text-base-content/50 mt-1">
                  {if diet.member, do: diet.member.user.name, else: "Unassigned"}
                  <%= if diet.dietary_type do %>
                    &middot; {format_dietary_type(diet.dietary_type)}
                  <% end %>
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
