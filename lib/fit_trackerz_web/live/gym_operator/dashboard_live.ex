defmodule FitTrackerzWeb.GymOperator.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, gyms} ->
        case gyms do
          [gym | _] ->
            member_count = length(gym.gym_members)

            pending_member_invites =
              Enum.count(gym.member_invitations, fn inv -> inv.status == :pending end)

            branch_ids = Enum.map(gym.branches, & &1.id)

            scheduled_classes =
              case FitTrackerz.Scheduling.list_classes_by_branch(branch_ids, actor: actor) do
                {:ok, classes} ->
                  classes
                  |> Enum.filter(fn sc -> sc.status == :scheduled end)
                  |> Enum.take(5)

                {:error, _} ->
                  []
              end

            plans =
              case FitTrackerz.Billing.list_plans_by_gym(gym.id, actor: actor) do
                {:ok, result} -> result
                {:error, _} -> []
              end

            gym_tier = gym.tier
            is_premium = gym_tier == :premium

            leaderboard_data =
              if is_premium do
                %{
                  attendance: FitTrackerz.Gamification.Leaderboard.attendance_leaders(gym.id, :month) |> Enum.take(5),
                  workouts: FitTrackerz.Gamification.Leaderboard.workout_leaders(gym.id, :month) |> Enum.take(5)
                }
              else
                %{attendance: [], workouts: []}
              end

            {:ok,
             assign(socket,
               page_title: "Gym Dashboard",
               gym: gym,
               has_gym: true,
               member_count: member_count,
               pending_member_invites: pending_member_invites,
               scheduled_classes: scheduled_classes,
               active_tab: "details",
               plans: plans,
               gym_tier: gym_tier,
               is_premium: is_premium,
               leaderboard_data: leaderboard_data
             )}

          [] ->
            {:ok,
             assign(socket,
               page_title: "Gym Dashboard",
               gym: nil,
               has_gym: false,
               member_count: 0,
               pending_member_invites: 0,
               scheduled_classes: [],
               gym_tier: :free,
               is_premium: false,
               leaderboard_data: %{attendance: [], workouts: []}
             )}
        end

      {:error, _} ->
        {:ok,
         assign(socket,
           page_title: "Gym Dashboard",
           gym: nil,
           has_gym: false,
           member_count: 0,
           pending_member_invites: 0,
           scheduled_classes: [],
           gym_tier: :free,
           is_premium: false,
           leaderboard_data: %{attendance: [], workouts: []}
         )}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%= if @has_gym do %>
          <.page_header title={@gym.name} subtitle="Manage your gym and members.">
            <:actions>
              <.badge variant={status_variant(@gym.status)}>{Phoenix.Naming.humanize(@gym.status)}</.badge>
              <.badge variant={if(@gym_tier == :premium, do: "primary", else: "neutral")} size="sm">
                {if @gym_tier == :premium, do: "Premium", else: "Free"}
              </.badge>
              <.button variant="primary" size="sm" icon="hero-user-plus-mini" navigate="/gym/members">Members</.button>
            </:actions>
          </.page_header>

          <%!-- Stats Grid --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            <.stat_card label="Active Members" value={@member_count} icon="hero-user-group-solid" color="primary" />
            <.stat_card label="Pending Invites" value={@pending_member_invites} icon="hero-envelope-solid" color="warning" />
            <.stat_card label="Plans" value={length(@plans)} icon="hero-credit-card-solid" color="accent" />
            <.stat_card label="Branches" value={length(@gym.branches)} icon="hero-map-pin-solid" color="secondary" />
          </div>

          <%!-- Tab Group --%>
          <.tab_group active={@active_tab} on_tab_change="switch_tab">
            <:tab id="details" label="Details" icon="hero-information-circle">
              <.card title="Gym Details">
                <:header_actions>
                  <.button variant="outline" size="sm" icon="hero-pencil-square" navigate="/gym/setup">Edit Details</.button>
                </:header_actions>
                <.detail_grid>
                  <:item label="Name">{@gym.name}</:item>
                  <:item label="Phone">{@gym.phone || "Not set"}</:item>
                  <:item label="Description">{@gym.description || "No description"}</:item>
                  <:item label="Status">
                    <.badge variant={status_variant(@gym.status)}>{Phoenix.Naming.humanize(@gym.status)}</.badge>
                  </:item>
                </.detail_grid>
              </.card>
            </:tab>

            <:tab id="pricing" label="Pricing" icon="hero-credit-card">
              <.card title="Subscription Plans">
                <:header_actions>
                  <.button variant="primary" size="sm" icon="hero-plus" navigate="/gym/plans">Add Plan</.button>
                </:header_actions>
                <%= for plan_type <- [:general, :personal_training] do %>
                  <% type_plans = Enum.filter(@plans, &(&1.plan_type == plan_type)) %>
                  <%= if type_plans != [] do %>
                    <h4 class="font-medium mt-4 mb-2 capitalize">{plan_type |> to_string() |> String.replace("_", " ")}</h4>
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                      <%= for plan <- Enum.sort_by(type_plans, & &1.price_in_paise) do %>
                        <div class="card bg-base-100 border border-base-300 shadow-sm">
                          <div class="card-body p-4 text-center">
                            <h5 class="font-semibold">{FitTrackerz.Billing.PricingHelpers.duration_label(plan.duration)}</h5>
                            <p class="text-2xl font-bold text-primary">
                              Rs{FitTrackerz.Billing.PricingHelpers.format_price(plan.price_in_paise)}
                            </p>
                            <% months = FitTrackerz.Billing.PricingHelpers.duration_months(plan.duration) %>
                            <%= if months && months > 1 do %>
                              <p class="text-sm text-base-content/60">
                                Rs{FitTrackerz.Billing.PricingHelpers.format_price(FitTrackerz.Billing.PricingHelpers.per_month_price(plan.price_in_paise, plan.duration))}/mo
                              </p>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                <% end %>
                <%= if @plans == [] do %>
                  <.empty_state icon="hero-credit-card" title="No Plans Yet" subtitle="Create subscription plans so members can sign up.">
                    <:action>
                      <.button variant="primary" icon="hero-plus" navigate="/gym/plans">Create Plans</.button>
                    </:action>
                  </.empty_state>
                <% end %>
              </.card>
            </:tab>

            <:tab id="gallery" label="Gallery" icon="hero-photo">
              <.card title="Photo Gallery">
                <:header_actions>
                  <.button variant="outline" size="sm" icon="hero-photo" navigate="/gym/setup">Manage Photos</.button>
                </:header_actions>
                <% all_gallery = Enum.flat_map(@gym.branches, fn b -> b.gallery_urls || [] end) %>
                <%= if all_gallery != [] do %>
                  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                    <%= for url <- all_gallery do %>
                      <img src={url} class="w-full h-32 rounded-lg object-cover" alt="Gallery" />
                    <% end %>
                  </div>
                <% else %>
                  <.empty_state icon="hero-photo" title="No Photos" subtitle="No gallery images uploaded yet." />
                <% end %>
              </.card>
            </:tab>

            <:tab id="equipment" label="Equipment" icon="hero-wrench-screwdriver">
              <.card title="Equipment & Services">
                <:header_actions>
                  <.button variant="outline" size="sm" icon="hero-pencil-square" navigate="/gym/setup">Edit Equipment</.button>
                </:header_actions>
                <%= if (@gym.equipment && @gym.equipment != []) || (@gym.services && @gym.services != []) do %>
                  <%= if @gym.equipment && @gym.equipment != [] do %>
                    <h4 class="font-medium mb-2">Equipment & Amenities</h4>
                    <div class="flex flex-wrap gap-2 mb-4">
                      <%= for item <- @gym.equipment do %>
                        <.badge variant="success">{item}</.badge>
                      <% end %>
                    </div>
                  <% end %>
                  <%= if @gym.services && @gym.services != [] do %>
                    <h4 class="font-medium mb-2">Services</h4>
                    <div class="flex flex-wrap gap-2">
                      <%= for item <- @gym.services do %>
                        <.badge variant="info">{item}</.badge>
                      <% end %>
                    </div>
                  <% end %>
                <% else %>
                  <.empty_state icon="hero-wrench-screwdriver" title="No Equipment Listed" subtitle="Add your gym's equipment and services." />
                <% end %>
              </.card>
            </:tab>

            <:tab id="branches" label="Branches" icon="hero-map-pin">
              <.card title="Branches">
                <:header_actions>
                  <.button variant="primary" size="sm" icon="hero-plus" navigate="/gym/setup">Manage Branches</.button>
                </:header_actions>
                <%= if @gym.branches != [] do %>
                  <div class="space-y-3">
                    <%= for branch <- @gym.branches do %>
                      <div class="flex items-start gap-4 p-3 rounded-lg bg-base-300/20">
                        <%= if branch.logo_url do %>
                          <img src={branch.logo_url} class="w-14 h-14 rounded-lg object-cover shrink-0" />
                        <% end %>
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2">
                            <p class="font-semibold text-sm">{branch.city}, {branch.state}</p>
                            <%= if branch.is_primary do %>
                              <.badge variant="primary" size="sm">Primary</.badge>
                            <% end %>
                          </div>
                          <p class="text-xs text-base-content/60 mt-0.5">{branch.address} -- {branch.postal_code}</p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <.empty_state icon="hero-map-pin" title="No Branches" subtitle="No branches added yet." />
                <% end %>
              </.card>
            </:tab>
          </.tab_group>

          <%= if @is_premium do %>
            <.card title="Top Members This Month" id="leaderboard-card">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h4 class="text-sm font-semibold text-base-content/50 mb-3">Attendance</h4>
                  <%= if @leaderboard_data.attendance == [] do %>
                    <p class="text-sm text-base-content/30">No activity yet</p>
                  <% else %>
                    <div class="space-y-2">
                      <%= for leader <- @leaderboard_data.attendance do %>
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <span class="text-sm font-bold text-base-content/40 w-6">{leader.rank}</span>
                            <.avatar name={leader.member_name} size="sm" />
                            <span class="text-sm">{leader.member_name}</span>
                          </div>
                          <span class="text-sm font-bold">{leader.value}</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <div>
                  <h4 class="text-sm font-semibold text-base-content/50 mb-3">Workouts</h4>
                  <%= if @leaderboard_data.workouts == [] do %>
                    <p class="text-sm text-base-content/30">No activity yet</p>
                  <% else %>
                    <div class="space-y-2">
                      <%= for leader <- @leaderboard_data.workouts do %>
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <span class="text-sm font-bold text-base-content/40 w-6">{leader.rank}</span>
                            <.avatar name={leader.member_name} size="sm" />
                            <span class="text-sm">{leader.member_name}</span>
                          </div>
                          <span class="text-sm font-bold">{leader.value}</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </.card>
          <% else %>
            <.card id="upgrade-prompt">
              <.empty_state
                icon="hero-arrow-trending-up"
                title="Unlock Premium Features"
                subtitle="Upgrade to Premium for leaderboards, QR check-in, unlimited members, and more. Contact the platform admin to upgrade."
              />
            </.card>
          <% end %>
        <% else %>
          <%!-- No Gym Setup --%>
          <.empty_state icon="hero-building-office-2-solid" title="Set Up Your Gym" subtitle="You haven't created a gym yet. Get started by setting up your gym profile and adding your first branch.">
            <:action>
              <.button variant="primary" size="lg" icon="hero-plus-mini" navigate="/gym/setup">Create Your Gym</.button>
            </:action>
          </.empty_state>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp status_variant(:verified), do: "success"
  defp status_variant(:pending_verification), do: "warning"
  defp status_variant(:suspended), do: "error"
  defp status_variant(_), do: "neutral"
end
