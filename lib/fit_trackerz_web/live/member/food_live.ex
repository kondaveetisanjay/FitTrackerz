defmodule FitTrackerzWeb.Member.FoodLive do
  use FitTrackerzWeb, :live_view

  @meal_types [{:breakfast, "Breakfast"}, {:lunch, "Lunch"}, {:dinner, "Dinner"}, {:snack, "Snack"}]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok, assign(socket, page_title: "Food Log", no_gym: true, entries: [], form: nil,
          calorie_target: nil, selected_date: Date.utc_today(), meal_types: @meal_types)}

      memberships ->
        membership = List.first(memberships)
        member_ids = Enum.map(memberships, & &1.id)
        today = Date.utc_today()

        calorie_target = get_calorie_target(member_ids, actor)

        entries = load_entries(member_ids, today, actor)
        form = new_form(today)

        {:ok,
         assign(socket,
           page_title: "Food Log",
           no_gym: false,
           membership: membership,
           member_ids: member_ids,
           entries: entries,
           form: form,
           calorie_target: calorie_target,
           selected_date: today,
           meal_types: @meal_types
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"food" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "food"))}
  end

  def handle_event("change_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        entries = load_entries(socket.assigns.member_ids, date, socket.assigns.current_user)
        form = new_form(date)
        {:noreply, assign(socket, selected_date: date, entries: entries, form: form)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save", %{"food" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    attrs = %{
      member_id: membership.id,
      gym_id: membership.gym_id,
      logged_on: socket.assigns.selected_date,
      meal_type: String.to_existing_atom(params["meal_type"]),
      food_name: params["food_name"],
      calories: parse_int(params["calories"]),
      protein_g: parse_decimal(params["protein_g"]),
      carbs_g: parse_decimal(params["carbs_g"]),
      fat_g: parse_decimal(params["fat_g"])
    }

    case FitTrackerz.Health.create_food_log(attrs, actor: actor) do
      {:ok, _entry} ->
        entries = load_entries(socket.assigns.member_ids, socket.assigns.selected_date, actor)
        form = new_form(socket.assigns.selected_date)

        {:noreply,
         socket
         |> put_flash(:info, "Food entry added!")
         |> assign(entries: entries, form: form)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    entry = Enum.find(socket.assigns.entries, &(&1.id == id))

    if entry do
      case FitTrackerz.Health.destroy_food_log(entry, actor: actor) do
        :ok ->
          entries = load_entries(socket.assigns.member_ids, socket.assigns.selected_date, actor)
          {:noreply, socket |> put_flash(:info, "Entry deleted.") |> assign(entries: entries)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Entry not found.")}
    end
  end

  defp get_calorie_target(member_ids, actor) do
    case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
      {:ok, [plan | _]} -> plan.calorie_target
      _ -> nil
    end
  end

  defp load_entries(member_ids, date, actor) do
    case FitTrackerz.Health.list_food_logs_by_date(member_ids, date, actor: actor) do
      {:ok, entries} -> entries
      _ -> []
    end
  end

  defp new_form(date) do
    to_form(%{
      "logged_on" => Date.to_iso8601(date),
      "meal_type" => "breakfast",
      "food_name" => "",
      "calories" => "",
      "protein_g" => "",
      "carbs_g" => "",
      "fat_g" => ""
    }, as: "food")
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil
  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> d
      :error -> nil
    end
  end

  defp total_calories(entries), do: Enum.reduce(entries, 0, &(&1.calories + &2))

  defp total_macro(entries, field) do
    entries
    |> Enum.map(&Map.get(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    |> Decimal.to_string(:normal)
  end

  defp calorie_pct(_entries, nil), do: 0
  defp calorie_pct(entries, target) when target > 0, do: min(round(total_calories(entries) / target * 100), 100)
  defp calorie_pct(_, _), do: 0

  defp meal_badge_class(:breakfast), do: "bg-info/15 text-info"
  defp meal_badge_class(:lunch), do: "bg-success/15 text-success"
  defp meal_badge_class(:dinner), do: "bg-warning/15 text-warning"
  defp meal_badge_class(:snack), do: "bg-accent/15 text-accent"
  defp meal_badge_class(_), do: "bg-base-300/30 text-base-content/50"

  defp format_meal_type(type), do: type |> to_string() |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Food Log" subtitle="Track your daily meals and calories." back_path="/member" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You need a gym membership to track your food intake."
        />
      <% else %>
        <div class="space-y-8">
          <%!-- Date Picker + Summary --%>
          <div class="flex flex-col sm:flex-row gap-4 sm:gap-6">
            <div>
              <input
                type="date"
                value={Date.to_iso8601(@selected_date)}
                phx-change="change_date"
                name="date"
                class="input input-bordered input-sm"
                id="food-date-picker"
              />
            </div>

            <div class="flex-1">
              <.card>
                <div class="flex items-center gap-6 flex-wrap">
                  <div>
                    <div class="text-xs text-base-content/40 uppercase font-medium">Calories</div>
                    <div class="flex items-baseline gap-1 mt-1">
                      <span class="text-2xl font-black text-warning">{total_calories(@entries)}</span>
                      <%= if @calorie_target do %>
                        <span class="text-sm text-base-content/50">/ {@calorie_target} target</span>
                      <% else %>
                        <span class="text-sm text-base-content/30">no target set</span>
                      <% end %>
                    </div>
                    <%= if @calorie_target do %>
                      <div class="mt-2">
                        <.progress_bar value={calorie_pct(@entries, @calorie_target)} color="warning" show_percentage={false} />
                      </div>
                    <% end %>
                  </div>
                  <div class="flex gap-4">
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Protein</div>
                      <div class="font-bold">{total_macro(@entries, :protein_g)}g</div>
                    </div>
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Carbs</div>
                      <div class="font-bold">{total_macro(@entries, :carbs_g)}g</div>
                    </div>
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Fat</div>
                      <div class="font-bold">{total_macro(@entries, :fat_g)}g</div>
                    </div>
                  </div>
                </div>
              </.card>
            </div>
          </div>

          <%!-- Add Food Form --%>
          <.card title="Add Food" id="food-form-card">
            <.form for={@form} id="food-form" phx-change="validate" phx-submit="save">
              <div class="flex flex-wrap gap-3 items-end">
                <div>
                  <.input field={@form[:meal_type]} type="select" label="Meal" options={Enum.map(@meal_types, fn {v, l} -> {l, to_string(v)} end)} required />
                </div>
                <div class="flex-1 min-w-[150px]">
                  <.input field={@form[:food_name]} type="text" label="Food Name" placeholder="e.g., Chicken Biryani" required />
                </div>
                <div>
                  <.input field={@form[:calories]} type="number" label="Calories" required />
                </div>
                <div>
                  <.input field={@form[:protein_g]} type="number" label="Protein (g)" step="0.1" />
                </div>
                <div>
                  <.input field={@form[:carbs_g]} type="number" label="Carbs (g)" step="0.1" />
                </div>
                <div>
                  <.input field={@form[:fat_g]} type="number" label="Fat (g)" step="0.1" />
                </div>
                <div class="mb-2">
                  <.button variant="primary" size="sm" icon="hero-plus" type="submit" id="add-food-btn">
                    Add
                  </.button>
                </div>
              </div>
            </.form>
          </.card>

          <%!-- Today's Entries --%>
          <.card id="food-entries-card">
            <:header_actions>
              <.badge variant="neutral">{length(@entries)} items</.badge>
            </:header_actions>
            <div>
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                {Calendar.strftime(@selected_date, "%b %d, %Y")}
              </h2>
              <%= if @entries == [] do %>
                <.empty_state
                  icon="hero-queue-list"
                  title="No Food Logged"
                  subtitle="No food logged for this day."
                />
              <% else %>
                <div class="space-y-2">
                  <%= for entry <- @entries do %>
                    <div
                      class="flex items-center justify-between p-3 rounded-xl bg-base-200/50"
                      id={"food-#{entry.id}"}
                    >
                      <div class="flex items-center gap-3">
                        <span class={"text-xs px-2 py-0.5 rounded font-medium #{meal_badge_class(entry.meal_type)}"}>
                          {format_meal_type(entry.meal_type)}
                        </span>
                        <span class="font-medium text-sm">{entry.food_name}</span>
                      </div>
                      <div class="flex items-center gap-4">
                        <span class="text-sm text-base-content/60">{entry.calories} kcal</span>
                        <.button
                          variant="ghost"
                          size="sm"
                          icon="hero-trash"
                          phx-click="delete"
                          phx-value-id={entry.id}
                          data-confirm="Delete this entry?"
                          class="text-error"
                          id={"delete-food-#{entry.id}"}
                        >
                        </.button>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </.card>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
