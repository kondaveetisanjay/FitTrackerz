defmodule FitconnexWeb.Member.DietLive do
  use FitconnexWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    uid = user.id

    memberships =
      try do
        Fitconnex.Gym.GymMember
        |> Ash.Query.filter(user_id == ^uid)
        |> Ash.Query.filter(is_active == true)
        |> Ash.Query.load([:gym, :assigned_trainer])
        |> Ash.read!()
      rescue
        _ -> []
      end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "My Diet Plan",
           memberships: [],
           diet_plans: [],
           no_gym: true
         )}

      memberships ->
        mids = Enum.map(memberships, & &1.id)

        diet_plans =
          try do
            Fitconnex.Training.DietPlan
            |> Ash.Query.filter(member_id in ^mids)
            |> Ash.Query.load([:gym, :trainer])
            |> Ash.read!()
          rescue
            _ -> []
          end

        {:ok,
         assign(socket,
           page_title: "My Diet Plan",
           memberships: memberships,
           diet_plans: diet_plans,
           no_gym: false
         )}
    end
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
              <p class="text-base-content/50 mt-1">View your personalized nutrition programs.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <%!-- No Gym Membership --%>
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
          <%= if @diet_plans == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-diet-plans">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-success/10 flex items-center justify-center mb-4">
                  <.icon name="hero-heart" class="size-8 text-success" />
                </div>
                <h2 class="text-lg font-bold">No Diet Plans Yet</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  Your trainer will create a nutrition plan based on your goals. Check back soon!
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
                  <%!-- Plan Header --%>
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
                            <.icon name="hero-user-mini" class="size-3" />
                            {plan.trainer.name}
                          </span>
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
                        <%!-- Macros --%>
                        <div class="flex flex-wrap items-center gap-3 text-xs">
                          <%= if meal.calories do %>
                            <span class="flex items-center gap-1 text-warning font-medium">
                              <.icon name="hero-fire-mini" class="size-3" />
                              {meal.calories} cal
                            </span>
                          <% end %>
                          <%= if meal.protein do %>
                            <span class="text-info font-medium">
                              P: {Float.round(meal.protein, 1)}g
                            </span>
                          <% end %>
                          <%= if meal.carbs do %>
                            <span class="text-accent font-medium">
                              C: {Float.round(meal.carbs, 1)}g
                            </span>
                          <% end %>
                          <%= if meal.fat do %>
                            <span class="text-error font-medium">F: {Float.round(meal.fat, 1)}g</span>
                          <% end %>
                        </div>
                      </div>
                      <%!-- Items --%>
                      <%= if meal.items != [] do %>
                        <div class="mt-3 flex flex-wrap gap-1.5">
                          <span
                            :for={item <- meal.items}
                            class="badge badge-ghost badge-sm"
                          >
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
