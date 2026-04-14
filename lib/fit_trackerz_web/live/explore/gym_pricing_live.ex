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
          <.page_header
            title="Choose Your Membership Plan"
            subtitle={"#{@gym.name}#{if @branch, do: " · #{@branch.city}, #{@branch.state}", else: ""}"}
            back_path={"/explore/#{@gym.slug}"}
          />

          <%!-- Plan Type Toggle --%>
          <.section>
            <div class="inline-flex rounded-full bg-base-200 p-1 border border-base-300/50">
              <button
                phx-click="switch_plan_type"
                phx-value-type="general"
                class={["px-6 py-2 rounded-full text-sm font-semibold transition-all", if(@active_plan_type == :general, do: "bg-primary text-primary-content shadow-md", else: "text-base-content/60 hover:text-base-content")]}
              >
                General Membership
              </button>
              <button
                phx-click="switch_plan_type"
                phx-value-type="personal_training"
                class={["px-6 py-2 rounded-full text-sm font-semibold transition-all", if(@active_plan_type == :personal_training, do: "bg-primary text-primary-content shadow-md", else: "text-base-content/60 hover:text-base-content")]}
              >
                Personal Training
              </button>
            </div>
          </.section>

          <%!-- Pricing Cards --%>
          <% type_plans = @plans |> Enum.filter(&(&1.plan_type == @active_plan_type)) |> Enum.sort_by(& &1.price_in_paise) %>
          <% base_monthly = if @active_plan_type == :general, do: @monthly_price, else: @monthly_pt_price %>

          <%= if type_plans != [] do %>
            <.section>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                <%= for plan <- type_plans do %>
                  <% months = PricingHelpers.duration_months(plan.duration) %>
                  <% per_month = PricingHelpers.per_month_price(plan.price_in_paise, plan.duration) %>
                  <% savings = if base_monthly, do: PricingHelpers.savings_percentage(plan.price_in_paise, plan.duration, base_monthly), else: 0 %>
                  <% is_recommended = savings >= 20 && savings <= 30 %>

                  <.card
                    class={if(is_recommended, do: "ring-2 ring-primary scale-105 shadow-xl", else: "")}
                    padded={false}
                  >
                    <%= if is_recommended do %>
                      <div class="bg-gradient-to-r from-primary to-primary/80 text-primary-content text-center py-1.5 text-xs font-bold uppercase tracking-wider">
                        Recommended
                      </div>
                    <% end %>
                    <div class="p-6 text-center">
                      <h3 class="text-lg font-bold uppercase tracking-wide">
                        {PricingHelpers.duration_label(plan.duration)}
                      </h3>

                      <p class="text-3xl font-bold text-primary mt-2">
                        Rs{PricingHelpers.format_price(plan.price_in_paise)}
                      </p>

                      <%= if months && months > 1 && per_month do %>
                        <p class="text-base-content/60">Rs{PricingHelpers.format_price(per_month)}/mo</p>
                        <%= if savings > 0 do %>
                          <.badge variant="success" class="mt-1">Save {savings}%</.badge>
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

                      <.button
                        variant={if(is_recommended, do: "primary", else: "outline")}
                        class="mt-4 w-full"
                        navigate="/register"
                      >
                        Select Plan
                      </.button>
                    </div>
                  </.card>
                <% end %>
              </div>
            </.section>

            <%!-- Comparison Table --%>
            <.section title="Plan Comparison">
              <.card padded={false}>
                <div class="overflow-x-auto">
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
                      <tr class="hover:bg-base-200/30">
                        <td>Gym Access</td>
                        <%= for _plan <- type_plans do %>
                          <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                        <% end %>
                      </tr>
                      <tr class="hover:bg-base-200/30">
                        <td>Group Classes</td>
                        <%= for _plan <- type_plans do %>
                          <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                        <% end %>
                      </tr>
                      <tr class="hover:bg-base-200/30">
                        <td>Locker Room</td>
                        <%= for _plan <- type_plans do %>
                          <td class="text-center"><.icon name="hero-check-circle-solid" class="size-5 text-success inline" /></td>
                        <% end %>
                      </tr>
                      <tr class="hover:bg-base-200/30">
                        <td class="font-semibold">Price</td>
                        <%= for plan <- type_plans do %>
                          <td class="text-center font-semibold">Rs{PricingHelpers.format_price(plan.price_in_paise)}</td>
                        <% end %>
                      </tr>
                      <tr class="hover:bg-base-200/30">
                        <td class="font-semibold">Per Month</td>
                        <%= for plan <- type_plans do %>
                          <% per_month = PricingHelpers.per_month_price(plan.price_in_paise, plan.duration) %>
                          <td class="text-center">
                            {if per_month, do: "Rs#{PricingHelpers.format_price(per_month)}", else: "-"}
                          </td>
                        <% end %>
                      </tr>
                      <tr class="hover:bg-base-200/30">
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
              </.card>
            </.section>
          <% else %>
            <.card>
              <.empty_state
                icon="hero-credit-card"
                title="No Plans Available"
                subtitle="No plans available for this category yet."
              />
            </.card>
          <% end %>

          <%!-- Bottom CTA --%>
          <.section>
            <.card>
              <div class="text-center">
                <p class="text-base-content/70 mb-2">Not sure which plan? Start with Monthly and upgrade anytime.</p>
                <.button variant="primary" navigate="/register">Register Free to Join</.button>
              </div>
            </.card>
          </.section>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
