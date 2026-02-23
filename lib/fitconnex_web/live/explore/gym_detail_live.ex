defmodule FitconnexWeb.Explore.GymDetailLive do
  use FitconnexWeb, :live_view

  alias Fitconnex.Billing.PricingHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    actor = socket.assigns.current_user

    case load_gym_by_slug(slug, actor) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Gym not found or not yet verified.")
         |> push_navigate(to: "/explore", replace: true)}

      gym_data ->
        {:noreply,
         assign(socket,
           page_title: gym_data.gym.name,
           gym: gym_data.gym,
           plans: gym_data.plans,
           class_defs: gym_data.class_defs,
           cheapest_monthly: gym_data.cheapest_monthly,
           monthly_price: gym_data.monthly_price,
           primary_branch: gym_data.primary_branch,
           all_gallery: gym_data.all_gallery
         )}
    end
  end

  defp load_gym_by_slug(slug, actor) do
    case Fitconnex.Gym.get_gym_by_slug(slug, actor: actor) do
      {:ok, gym} ->
        gym_id = gym.id

        plans =
          case Fitconnex.Billing.list_plans_by_gym(gym_id, actor: actor) do
            {:ok, result} -> Enum.sort_by(result, & &1.price_in_paise)
            {:error, _} -> []
          end

        class_defs =
          case Fitconnex.Scheduling.list_class_definitions_by_gym(gym_id, actor: actor) do
            {:ok, result} -> result
            {:error, _} -> []
          end

        primary_branch =
          Enum.find(gym.branches, & &1.is_primary) || List.first(gym.branches)

        all_gallery =
          Enum.flat_map(gym.branches, fn b -> b.gallery_urls || [] end)

        cheapest_monthly =
          plans
          |> Enum.filter(fn p -> p.duration == :monthly end)
          |> Enum.map(& &1.price_in_paise)
          |> Enum.min(fn -> nil end)

        monthly_price =
          plans
          |> Enum.filter(&(&1.plan_type == :general && &1.duration == :monthly))
          |> Enum.map(& &1.price_in_paise)
          |> List.first()

        %{
          gym: gym,
          plans: plans,
          class_defs: class_defs,
          cheapest_monthly: cheapest_monthly,
          monthly_price: monthly_price,
          primary_branch: primary_branch,
          all_gallery: all_gallery
        }

      {:error, _} ->
        nil
    end
  end

  defp directions_url(lat, lng) when is_number(lat) and is_number(lng) do
    "https://www.google.com/maps/dir/?api=1&destination=#{lat},#{lng}"
  end

  defp directions_url(_, _), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%= if assigns[:gym] do %>
        <div class="max-w-6xl mx-auto">
          <%!-- Back to Explore --%>
          <div class="mb-4">
            <a href="/explore" class="btn btn-ghost btn-sm gap-1">
              <.icon name="hero-arrow-left-mini" class="size-4" /> Back to Explore
            </a>
          </div>

          <%!-- Photo Gallery Grid --%>
          <%= if @all_gallery != [] do %>
            <div class="grid grid-cols-4 gap-2 rounded-2xl overflow-hidden mb-8" style="max-height: 320px;">
              <%= for {url, idx} <- Enum.with_index(Enum.take(@all_gallery, 4)) do %>
                <%= if idx == 0 do %>
                  <div class="col-span-2 row-span-2">
                    <img src={url} class="w-full h-full object-cover hover:scale-105 transition-transform duration-300" alt={"#{@gym.name} photo"} />
                  </div>
                <% else %>
                  <div class="relative">
                    <img src={url} class="w-full h-full object-cover hover:scale-105 transition-transform duration-300" alt={"#{@gym.name} photo"} />
                    <%= if idx == 3 && length(@all_gallery) > 4 do %>
                      <div class="absolute inset-0 bg-black/50 flex items-center justify-center text-white font-bold text-lg">
                        +{length(@all_gallery) - 4} more
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% else %>
            <%!-- Fallback hero banner --%>
            <div class="mb-8 rounded-xl overflow-hidden">
              <%= if @primary_branch && @primary_branch.logo_url do %>
                <img
                  src={@primary_branch.logo_url}
                  alt={@gym.name}
                  class="w-full h-48 sm:h-64 object-cover"
                />
              <% else %>
                <div class="w-full h-48 sm:h-56 bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 flex items-center justify-center relative overflow-hidden">
                  <div class="absolute top-6 right-10 w-32 h-32 border-2 border-primary/10 rounded-full"></div>
                  <div class="absolute bottom-6 left-10 w-24 h-24 border-2 border-secondary/10 rounded-xl rotate-12"></div>
                  <div class="absolute top-1/2 left-1/4 w-16 h-16 border-2 border-primary/5 rounded-full"></div>
                  <div class="text-center relative z-10">
                    <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto border border-primary/20 mb-3">
                      <.icon name="hero-building-office-2-solid" class="size-10 text-primary/40" />
                    </div>
                    <p class="text-sm text-base-content/40 font-semibold">{@gym.name}</p>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <%!-- Two-Column: Info + Map --%>
          <div class="grid grid-cols-1 lg:grid-cols-5 gap-8 mb-8">
            <%!-- Left: Info (3 cols) --%>
            <div class="lg:col-span-3">
              <div class="flex items-center gap-3 flex-wrap">
                <h1 class="text-3xl font-brand">{@gym.name}</h1>
                <span class="badge badge-sm badge-success gap-1">
                  <.icon name="hero-check-badge-mini" class="size-3" /> Verified
                </span>
                <%= if @gym.is_promoted do %>
                  <span class="badge badge-sm badge-warning gap-1">
                    <.icon name="hero-star-mini" class="size-3" /> Featured
                  </span>
                <% end %>
              </div>

              <p class="text-base-content/50 mt-1">
                {length(@class_defs)} class types · {length(@plans)} plans
              </p>

              <%= if @gym.phone do %>
                <p class="mt-3 flex items-center gap-2 text-base-content/70">
                  <.icon name="hero-phone-mini" class="size-4" /> {@gym.phone}
                </p>
              <% end %>

              <%= if @cheapest_monthly do %>
                <p class="mt-2">
                  Starting at
                  <span class="font-bold text-primary text-lg">
                    Rs {PricingHelpers.format_price(@cheapest_monthly)}/mo
                  </span>
                </p>
              <% end %>

              <%= if @gym.description do %>
                <p class="mt-4 text-base-content/80 whitespace-pre-wrap leading-relaxed">
                  {@gym.description}
                </p>
              <% end %>
            </div>

            <%!-- Right: Location + Map (2 cols) --%>
            <div class="lg:col-span-2">
              <%= if @primary_branch do %>
                <div class="glass-card">
                  <div class="card-body p-5">
                    <h3 class="font-semibold flex items-center gap-2 mb-3">
                      <.icon name="hero-map-pin-solid" class="size-5 text-error" /> Location
                    </h3>
                    <p class="text-sm text-base-content/70">
                      {@primary_branch.address}
                    </p>
                    <p class="text-sm font-medium mt-1">
                      {@primary_branch.city}, {@primary_branch.state} {@primary_branch.postal_code}
                    </p>

                    <%= if @primary_branch.latitude && @primary_branch.longitude do %>
                      <div
                        id="gym-detail-map"
                        phx-hook="GymDetailMap"
                        data-lat={@primary_branch.latitude}
                        data-lng={@primary_branch.longitude}
                        class="w-full h-48 rounded-lg bg-base-300 mt-3 shadow-lg"
                      >
                      </div>
                      <a
                        href={directions_url(@primary_branch.latitude, @primary_branch.longitude)}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="btn btn-ghost btn-sm gap-1 mt-2"
                      >
                        <.icon name="hero-arrow-top-right-on-square-mini" class="size-4" />
                        Get Directions
                      </a>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Quick Stats --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-8">
            <div class="glass-card flex items-center gap-3 p-3">
              <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                <.icon name="hero-map-pin-solid" class="size-5 text-primary" />
              </div>
              <div>
                <p class="text-lg font-bold text-primary">{length(@gym.branches)}</p>
                <p class="text-xs text-base-content/50">Location(s)</p>
              </div>
            </div>
            <div class="glass-card flex items-center gap-3 p-3">
              <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                <.icon name="hero-calendar-days-solid" class="size-5 text-primary" />
              </div>
              <div>
                <p class="text-lg font-bold text-primary">{length(@class_defs)}</p>
                <p class="text-xs text-base-content/50">Class Types</p>
              </div>
            </div>
            <div class="glass-card flex items-center gap-3 p-3">
              <div class="w-10 h-10 rounded-lg bg-secondary/10 flex items-center justify-center shrink-0">
                <.icon name="hero-credit-card-solid" class="size-5 text-secondary" />
              </div>
              <div>
                <p class="text-lg font-bold text-primary">{length(@plans)}</p>
                <p class="text-xs text-base-content/50">Plans</p>
              </div>
            </div>
          </div>

          <%!-- Membership Plans --%>
          <%= if @plans != [] do %>
            <section class="mb-8">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-2xl font-brand">Membership Plans</h2>
                <a href={"/explore/#{@gym.slug}/pricing"} class="btn btn-ghost btn-sm gap-1">
                  View All Plans <.icon name="hero-arrow-right-mini" class="size-4" />
                </a>
              </div>

              <%= for plan_type <- [:general, :personal_training] do %>
                <% type_plans = Enum.filter(@plans, &(&1.plan_type == plan_type)) |> Enum.sort_by(& &1.price_in_paise) %>
                <%= if type_plans != [] do %>
                  <h3 class="font-semibold mt-4 mb-3 capitalize text-base-content/70">
                    {plan_type |> to_string() |> String.replace("_", " ")}
                  </h3>
                  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <%= for plan <- type_plans do %>
                      <% months = PricingHelpers.duration_months(plan.duration) %>
                      <% per_month = PricingHelpers.per_month_price(plan.price_in_paise, plan.duration) %>
                      <% savings = if @monthly_price, do: PricingHelpers.savings_percentage(plan.price_in_paise, plan.duration, @monthly_price), else: 0 %>
                      <div class={["glass-card overflow-hidden", if(savings > 25, do: "ring-2 ring-primary", else: "")]}>
                        <%= if savings > 25 do %>
                          <div class="bg-gradient-to-r from-primary to-primary/80 text-primary-content text-center py-1.5 text-xs font-bold uppercase tracking-wider">
                            Best Value
                          </div>
                        <% end %>
                        <div class="card-body p-4 text-center">
                          <h4 class="font-semibold">{PricingHelpers.duration_label(plan.duration)}</h4>
                          <p class="text-2xl font-bold text-primary mt-1">
                            Rs{PricingHelpers.format_price(plan.price_in_paise)}
                          </p>
                          <%= if months && months > 1 && per_month do %>
                            <p class="text-sm text-base-content/60">
                              Rs{PricingHelpers.format_price(per_month)}/mo
                            </p>
                            <%= if savings > 0 do %>
                              <span class="badge badge-success badge-sm mt-1">Save {savings}%</span>
                            <% end %>
                          <% end %>
                          <a href="/register" class="btn btn-primary btn-sm mt-3">Join Now</a>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </section>
          <% end %>

          <%!-- Equipment & Amenities --%>
          <%= if (@gym.equipment && @gym.equipment != []) || (@gym.services && @gym.services != []) do %>
            <section class="mb-8">
              <h2 class="text-2xl font-brand mb-4">Equipment & Amenities</h2>
              <div class="flex flex-wrap gap-2">
                <%= for item <- (@gym.equipment || []) ++ (@gym.services || []) do %>
                  <span class="badge badge-lg badge-outline gap-1 backdrop-blur-sm">
                    <.icon name="hero-check-circle-solid" class="size-4 text-success" />
                    {item}
                  </span>
                <% end %>
              </div>
            </section>
          <% end %>

          <%!-- Classes & Services --%>
          <%= if @class_defs != [] do %>
            <section class="mb-8">
              <h2 class="text-2xl font-brand mb-4">Classes & Services</h2>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                <%= for class_def <- @class_defs do %>
                  <div class="card bg-base-200/50 border border-base-300/50">
                    <div class="card-body p-4">
                      <h4 class="font-semibold">{class_def.name}</h4>
                      <div class="flex items-center gap-2 mt-1">
                        <span class="badge badge-xs badge-outline">
                          {Phoenix.Naming.humanize(class_def.class_type)}
                        </span>
                        <span class="text-xs text-base-content/50">
                          {class_def.default_duration_minutes} min
                        </span>
                        <%= if class_def.max_participants do %>
                          <span class="text-xs text-base-content/50">
                            · Max {class_def.max_participants}
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </section>
          <% end %>

          <%!-- Bottom CTA Banner --%>
          <section class="bg-gradient-to-br from-primary/10 via-base-200 to-secondary/5 rounded-2xl p-8 text-center mt-8 relative overflow-hidden">
            <div class="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full -translate-y-1/2 translate-x-1/2"></div>
            <div class="absolute bottom-0 left-0 w-24 h-24 bg-secondary/5 rounded-full translate-y-1/2 -translate-x-1/2"></div>
            <h2 class="text-2xl font-brand mb-2">Ready to start your fitness journey?</h2>
            <p class="text-base-content/70 mb-4">
              Join {@gym.name} today and transform your life.
            </p>
            <a href="/register" class="btn btn-primary btn-lg gap-2">
              <.icon name="hero-rocket-launch-mini" class="size-5" />
              Register Free & Join
            </a>
          </section>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
