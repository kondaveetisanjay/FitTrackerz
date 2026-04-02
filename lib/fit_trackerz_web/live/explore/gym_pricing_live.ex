defmodule FitTrackerzWeb.Explore.GymPricingLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Billing.PricingHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.get_gym_by_slug(slug, actor: actor) do
      {:ok, gym} ->
        plans =
          case FitTrackerz.Billing.list_plans_by_gym(gym.id, actor: actor) do
            {:ok, result} -> result
            {:error, _} -> []
          end

        branch =
          Enum.find(gym.branches, & &1.is_primary) || List.first(gym.branches)

        monthly_price =
          plans
          |> Enum.filter(&(&1.plan_type == :general && &1.duration == :monthly))
          |> Enum.map(& &1.price_in_paise)
          |> List.first()

        monthly_pt_price =
          plans
          |> Enum.filter(&(&1.plan_type == :personal_training && &1.duration == :monthly))
          |> Enum.map(& &1.price_in_paise)
          |> List.first()

        {:noreply,
         assign(socket,
           page_title: "Plans - #{gym.name}",
           gym: gym,
           branch: branch,
           plans: plans,
           monthly_price: monthly_price,
           monthly_pt_price: monthly_pt_price,
           active_plan_type: :general
         )}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Gym not found.")
         |> push_navigate(to: "/explore", replace: true)}
    end
  end

  @impl true
  def handle_event("switch_plan_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :active_plan_type, String.to_existing_atom(type))}
  end

  defp default_features(:monthly), do: ["Full gym access", "Group classes", "Locker room"]
  defp default_features(:quarterly), do: ["Full gym access", "Group classes", "Locker room", "1 Guest pass"]
  defp default_features(:half_yearly), do: ["Full gym access", "Group classes", "Locker room", "2 Guest passes", "Diet consultation"]
  defp default_features(:annual), do: ["Full gym access", "Group classes", "Locker room", "4 Guest passes", "Diet consultation", "Free merchandise"]
  defp default_features(:two_year), do: ["Full gym access", "Group classes", "Locker room", "6 Guest passes", "Diet consultation", "Free merchandise", "Priority booking"]
  defp default_features(_), do: ["Full gym access"]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%= if assigns[:gym] do %>
        <div class="max-w-6xl mx-auto">
          <%!-- Back link --%>
          <div class="mb-4">
            <a href={"/explore/#{@gym.slug}"} class="btn btn-ghost btn-sm gap-1">
              <.icon name="hero-arrow-left-mini" class="size-4" /> Back to {@gym.name}
            </a>
          </div>

          <h1 class="text-3xl font-brand">Choose Your Membership Plan</h1>
          <p class="text-base-content/60 mt-1">
            {@gym.name}
            <%= if @branch do %>
              · {@branch.city}, {@branch.state}
            <% end %>
          </p>

          <%!-- Plan Type Toggle --%>
          <div class="inline-flex rounded-full bg-base-200 p-1 mt-6 mb-8 border border-base-200/50">
            <button
              phx-click="switch_plan_type"
              phx-value-type="general"
              class={["px-6 py-2 rounded-full text-sm font-semibold transition-all press-scale", if(@active_plan_type == :general, do: "bg-primary text-primary-content shadow-md", else: "text-base-content/60 hover:text-base-content")]}
            >
              General Membership
            </button>
            <button
              phx-click="switch_plan_type"
              phx-value-type="personal_training"
              class={["px-6 py-2 rounded-full text-sm font-semibold transition-all press-scale", if(@active_plan_type == :personal_training, do: "bg-primary text-primary-content shadow-md", else: "text-base-content/60 hover:text-base-content")]}
            >
              Personal Training
            </button>
          </div>

          <%!-- Pricing Cards --%>
          <% type_plans = @plans |> Enum.filter(&(&1.plan_type == @active_plan_type)) |> Enum.sort_by(& &1.price_in_paise) %>
          <% base_monthly = if @active_plan_type == :general, do: @monthly_price, else: @monthly_pt_price %>

          <%= if type_plans != [] do %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <%= for plan <- type_plans do %>
                <% months = PricingHelpers.duration_months(plan.duration) %>
                <% per_month = PricingHelpers.per_month_price(plan.price_in_paise, plan.duration) %>
                <% savings = if base_monthly, do: PricingHelpers.savings_percentage(plan.price_in_paise, plan.duration, base_monthly), else: 0 %>
                <% is_recommended = savings >= 20 && savings <= 30 %>

                <div class={[
                  "ft-card overflow-hidden",
                  if(is_recommended, do: "ring-2 ring-primary scale-105 shadow-xl", else: "")
                ]}>
                  <%= if is_recommended do %>
                    <div class="bg-gradient-to-r from-primary to-primary/80 text-primary-content text-center py-1.5 text-xs font-bold uppercase tracking-wider">
                      Recommended
                    </div>
                  <% end %>
                  <div class="card-body p-6 text-center">
                    <h3 class="text-lg font-bold uppercase tracking-wide">
                      {PricingHelpers.duration_label(plan.duration)}
                    </h3>

                    <p class="text-3xl font-bold text-primary mt-2">
                      Rs{PricingHelpers.format_price(plan.price_in_paise)}
                    </p>

                    <%= if months && months > 1 && per_month do %>
                      <p class="text-base-content/60">Rs{PricingHelpers.format_price(per_month)}/mo</p>
                      <%= if savings > 0 do %>
                        <span class="badge badge-success mt-1">Save {savings}%</span>
                      <% end %>
                    <% else %>
                      <p class="text-base-content/60">/month</p>
                    <% end %>

                    <div class="divider my-3"></div>

                    <%!-- Feature list --%>
                    <ul class="text-left space-y-2 text-sm">
                      <%= for feature <- (plan.features || default_features(plan.duration)) do %>
                        <li class="flex items-center gap-2">
                          <.icon name="hero-check-circle-solid" class="size-4 text-success shrink-0" />
                          {feature}
                        </li>
                      <% end %>
                    </ul>

                    <a href="/register" class={[
                      "btn mt-4 w-full press-scale",
                      if(is_recommended, do: "btn-primary", else: "btn-outline btn-primary")
                    ]}>
                      Select Plan
                    </a>
                  </div>
                </div>
              <% end %>
            </div>

            <%!-- Comparison Table --%>
            <div class="ft-card mt-12 p-6">
              <h2 class="text-xl font-brand mb-4">Plan Comparison</h2>
              <div class="ft-table overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>Feature</th>
                      <%= for plan <- type_plans do %>
                        <th class="text-center">{PricingHelpers.duration_label(plan.duration)}</th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody>
                    <tr class="hover:bg-base-200/50">
                      <td>Gym Access</td>
                      <%= for _plan <- type_plans do %>
                        <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                      <% end %>
                    </tr>
                    <tr class="hover:bg-base-200/50">
                      <td>Group Classes</td>
                      <%= for _plan <- type_plans do %>
                        <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                      <% end %>
                    </tr>
                    <tr class="hover:bg-base-200/50">
                      <td>Locker Room</td>
                      <%= for _plan <- type_plans do %>
                        <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                      <% end %>
                    </tr>
                    <tr class="hover:bg-base-200/50">
                      <td class="font-semibold">Price</td>
                      <%= for plan <- type_plans do %>
                        <td class="text-center font-semibold">Rs{PricingHelpers.format_price(plan.price_in_paise)}</td>
                      <% end %>
                    </tr>
                    <tr class="hover:bg-base-200/50">
                      <td class="font-semibold">Per Month</td>
                      <%= for plan <- type_plans do %>
                        <% per_month = PricingHelpers.per_month_price(plan.price_in_paise, plan.duration) %>
                        <td class="text-center">
                          {if per_month, do: "Rs#{PricingHelpers.format_price(per_month)}", else: "-"}
                        </td>
                      <% end %>
                    </tr>
                    <tr class="hover:bg-base-200/50">
                      <td class="font-semibold">Total Savings</td>
                      <%= for plan <- type_plans do %>
                        <% savings = if base_monthly do
                          months = PricingHelpers.duration_months(plan.duration)
                          if months && months > 1, do: base_monthly * months - plan.price_in_paise, else: 0
                        else
                          0
                        end %>
                        <td class="text-center text-success font-semibold">
                          {if savings > 0, do: "Rs#{PricingHelpers.format_price(savings)}", else: "-"}
                        </td>
                      <% end %>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          <% else %>
            <div class="text-center py-12 text-base-content/50">
              <.icon name="hero-credit-card" class="size-12 mx-auto mb-3 opacity-30" />
              <p>No plans available for this category yet.</p>
            </div>
          <% end %>

          <%!-- Bottom CTA --%>
          <div class="bg-gradient-to-br from-primary/10 via-base-200 to-secondary/5 rounded-2xl p-8 text-center mt-12 relative overflow-hidden">
            <div class="absolute top-0 right-0 w-28 h-28 bg-primary/5 rounded-full -translate-y-1/2 translate-x-1/2"></div>
            <div class="absolute bottom-0 left-0 w-20 h-20 bg-secondary/5 rounded-full translate-y-1/2 -translate-x-1/2"></div>
            <div class="relative z-10">
              <p class="text-base-content/70 mb-2">Not sure which plan? Start with Monthly and upgrade anytime.</p>
              <a href="/register" class="btn btn-primary press-scale">Register Free to Join</a>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
