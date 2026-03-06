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

            {:ok,
             assign(socket,
               page_title: "Gym Dashboard",
               gym: gym,
               has_gym: true,
               member_count: member_count,
               pending_member_invites: pending_member_invites,
               scheduled_classes: scheduled_classes,
               active_tab: "details",
               plans: plans
             )}

          [] ->
            {:ok,
             assign(socket,
               page_title: "Gym Dashboard",
               gym: nil,
               has_gym: false,
               member_count: 0,
               pending_member_invites: 0,
               scheduled_classes: []
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
           scheduled_classes: []
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
      <div class="space-y-8">
        <%= if @has_gym do %>
          <%!-- Page Header --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <div class="flex items-center gap-3">
                <h1 class="text-2xl sm:text-3xl font-brand">{@gym.name}</h1>

                <span class={[
                  "badge badge-sm",
                  @gym.status == :verified && "badge-success",
                  @gym.status == :pending_verification && "badge-warning",
                  @gym.status == :suspended && "badge-error"
                ]}>
                  {Phoenix.Naming.humanize(@gym.status)}
                </span>
              </div>

              <p class="text-base-content/50 mt-1">Manage your gym and members.</p>
            </div>

            <div class="flex gap-2">
              <.link navigate="/gym/members" class="btn btn-primary btn-sm gap-2 font-semibold">
                <.icon name="hero-user-plus-mini" class="size-4" /> Members
              </.link>
            </div>
          </div>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.link
              navigate="/gym/members"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-members"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Members
                    </p>

                    <p class="text-3xl font-black mt-1">{@member_count}</p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-primary" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Active members</p>
              </div>
            </.link>
            <.link
              navigate="/gym/invitations"
              class="card bg-base-200/50 border border-base-300/50 hover:shadow-md"
              id="stat-invites"
            >
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Pending Invites
                    </p>

                    <p class="text-3xl font-black mt-1">
                      {@pending_member_invites}
                    </p>
                  </div>

                  <div class="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center">
                    <.icon name="hero-envelope-solid" class="size-6 text-warning" />
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-2">Awaiting response</p>
              </div>
            </.link>
          </div>
          <%!-- Tab Navigation --%>
          <div class="border-b border-base-300/50">
            <div class="flex gap-0 overflow-x-auto">
              <%= for {label, tab_id, icon} <- [
                {"Details", "details", "hero-information-circle"},
                {"Pricing", "pricing", "hero-credit-card"},
                {"Gallery", "gallery", "hero-photo"},
                {"Equipment", "equipment", "hero-wrench-screwdriver"},
                {"Branches", "branches", "hero-map-pin"}
              ] do %>
                <button
                  phx-click="switch_tab"
                  phx-value-tab={tab_id}
                  class={[
                    "btn btn-ghost btn-sm gap-2 rounded-none border-b-2 font-medium",
                    if(@active_tab == tab_id, do: "border-primary text-primary", else: "border-transparent text-base-content/60")
                  ]}
                >
                  <.icon name={icon} class="size-4" /> {label}
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Tab Content --%>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-5">
              <%= case @active_tab do %>
                <% "details" -> %>
                  <h3 class="text-lg font-bold mb-4">Gym Details</h3>
                  <div class="space-y-3">
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <span class="text-sm font-semibold text-base-content/60 w-24">Name</span>
                      <span class="text-sm font-medium">{@gym.name}</span>
                    </div>
                    <%= if @gym.phone do %>
                      <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                        <span class="text-sm font-semibold text-base-content/60 w-24">Phone</span>
                        <span class="text-sm font-medium">{@gym.phone}</span>
                      </div>
                    <% end %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <span class="text-sm font-semibold text-base-content/60 w-24">Description</span>
                      <span class="text-sm font-medium">{@gym.description || "No description"}</span>
                    </div>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                      <span class="text-sm font-semibold text-base-content/60 w-24">Status</span>
                      <span class={"badge badge-sm #{if @gym.status == :verified, do: "badge-success", else: "badge-warning"}"}>
                        {Phoenix.Naming.humanize(@gym.status)}
                      </span>
                    </div>
                  </div>
                  <div class="mt-4">
                    <.link navigate="/gym/setup" class="btn btn-outline btn-primary btn-sm gap-2">
                      <.icon name="hero-pencil-square" class="size-4" /> Edit Details
                    </.link>
                  </div>

                <% "pricing" -> %>
                  <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-bold">Subscription Plans</h3>
                    <.link navigate="/gym/plans" class="btn btn-primary btn-sm gap-2">
                      <.icon name="hero-plus" class="size-4" /> Add Plan
                    </.link>
                  </div>

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
                    <p class="text-base-content/50 text-sm">No plans created yet.</p>
                  <% end %>

                <% "gallery" -> %>
                  <h3 class="text-lg font-bold mb-4">Photo Gallery</h3>
                  <% all_gallery = Enum.flat_map(@gym.branches, fn b -> b.gallery_urls || [] end) %>
                  <%= if all_gallery != [] do %>
                    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                      <%= for url <- all_gallery do %>
                        <img src={url} class="w-full h-32 rounded-lg object-cover" alt="Gallery" />
                      <% end %>
                    </div>
                  <% else %>
                    <p class="text-base-content/50 text-sm">No gallery images uploaded yet.</p>
                  <% end %>
                  <div class="mt-4">
                    <.link navigate="/gym/setup" class="btn btn-outline btn-primary btn-sm gap-2">
                      <.icon name="hero-photo" class="size-4" /> Manage Photos
                    </.link>
                  </div>

                <% "equipment" -> %>
                  <h3 class="text-lg font-bold mb-4">Equipment & Services</h3>
                  <%= if (@gym.equipment && @gym.equipment != []) || (@gym.services && @gym.services != []) do %>
                    <%= if @gym.equipment && @gym.equipment != [] do %>
                      <h4 class="font-medium mb-2">Equipment & Amenities</h4>
                      <div class="flex flex-wrap gap-2 mb-4">
                        <%= for item <- @gym.equipment do %>
                          <span class="badge badge-lg badge-outline gap-1">
                            <.icon name="hero-check-circle-solid" class="size-4 text-success" />
                            {item}
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                    <%= if @gym.services && @gym.services != [] do %>
                      <h4 class="font-medium mb-2">Services</h4>
                      <div class="flex flex-wrap gap-2">
                        <%= for item <- @gym.services do %>
                          <span class="badge badge-lg badge-outline gap-1">
                            <.icon name="hero-check-circle-solid" class="size-4 text-success" />
                            {item}
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  <% else %>
                    <p class="text-base-content/50 text-sm">No equipment or services listed yet.</p>
                  <% end %>
                  <div class="mt-4">
                    <.link navigate="/gym/setup" class="btn btn-outline btn-primary btn-sm gap-2">
                      <.icon name="hero-pencil-square" class="size-4" /> Edit Equipment
                    </.link>
                  </div>

                <% "branches" -> %>
                  <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-bold">Branches</h3>
                    <.link navigate="/gym/setup" class="btn btn-primary btn-sm gap-2">
                      <.icon name="hero-plus" class="size-4" /> Manage Branches
                    </.link>
                  </div>
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
                                <span class="badge badge-xs badge-primary">Primary</span>
                              <% end %>
                            </div>
                            <p class="text-xs text-base-content/60 mt-0.5">{branch.address} — {branch.postal_code}</p>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <p class="text-base-content/50 text-sm">No branches added yet.</p>
                  <% end %>
              <% end %>
            </div>
          </div>
        <% else %>
          <%!-- No Gym Setup --%>
          <div class="min-h-[60vh] flex items-center justify-center">
            <div class="text-center max-w-md">
              <div class="w-20 h-20 rounded-3xl bg-primary/10 flex items-center justify-center mx-auto mb-6">
                <.icon name="hero-building-office-2-solid" class="size-10 text-primary" />
              </div>

              <h1 class="text-2xl font-brand">Set Up Your Gym</h1>

              <p class="text-base-content/50 mt-3">
                You haven't created a gym yet. Get started by setting up your gym profile and adding your first branch.
              </p>

              <.link navigate="/gym/setup" class="btn btn-primary btn-lg gap-2 mt-8 font-bold">
                <.icon name="hero-plus-mini" class="size-5" /> Create Your Gym
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
