defmodule FitTrackerzWeb.Explore.GymDetailLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Billing.PricingHelpers

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
    case FitTrackerz.Gym.get_gym_by_slug(slug, actor: actor) do
      {:ok, gym} ->
        gym_id = gym.id

        plans =
          case FitTrackerz.Billing.list_plans_by_gym(gym_id, actor: actor) do
            {:ok, result} -> Enum.sort_by(result, & &1.price_in_paise)
            {:error, _} -> []
          end

        class_defs =
          case FitTrackerz.Scheduling.list_class_definitions_by_gym(gym_id, actor: actor) do
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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <%= if assigns[:gym] do %>
        <div class="max-w-6xl mx-auto">
          <.page_header title={@gym.name} back_path="/explore">
            <:actions>
              <.badge variant="success">Verified</.badge>
              <%= if @gym.is_promoted do %>
                <.badge variant="warning">Featured</.badge>
              <% end %>
            </:actions>
          </.page_header>

          <%!-- Photo Gallery Grid --%>
          <%= if @all_gallery != [] do %>
            <.section>
              <div class="grid grid-cols-4 gap-2 rounded-2xl overflow-hidden" style="max-height: 320px;">
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
            </.section>
          <% else %>
            <%!-- Fallback hero banner --%>
            <.section>
              <%= if @primary_branch && @primary_branch.logo_url do %>
                <div class="rounded-xl overflow-hidden">
                  <img
                    src={@primary_branch.logo_url}
                    alt={@gym.name}
                    class="w-full h-48 sm:h-64 object-cover"
                  />
                </div>
              <% else %>
                <div class="w-full h-48 sm:h-56 bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 flex items-center justify-center rounded-xl overflow-hidden">
                  <div class="text-center">
                    <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto border border-primary/20 mb-3">
                      <.icon name="hero-building-office-2-solid" class="size-10 text-primary/40" />
                    </div>
                    <p class="text-sm text-base-content/40 font-semibold">{@gym.name}</p>
                  </div>
                </div>
              <% end %>
            </.section>
          <% end %>

          <%!-- Two-Column: Info + Map --%>
          <.section>
            <div class="grid grid-cols-1 lg:grid-cols-5 gap-8">
              <%!-- Left: Info (3 cols) --%>
              <div class="lg:col-span-3 space-y-3">
                <p class="text-base-content/50">
                  {length(@class_defs)} class types · {length(@plans)} plans
                </p>

                <%= if @gym.phone do %>
                  <p class="flex items-center gap-2 text-base-content/70">
                    <.icon name="hero-phone-mini" class="size-4" /> {@gym.phone}
                  </p>
                <% end %>

                <%= if @cheapest_monthly do %>
                  <p>
                    Starting at
                    <span class="font-bold text-primary text-lg">
                      Rs {PricingHelpers.format_price(@cheapest_monthly)}/mo
                    </span>
                  </p>
                <% end %>

                <%= if @gym.description do %>
                  <p class="text-base-content/80 whitespace-pre-wrap leading-relaxed mt-2">
                    {@gym.description}
                  </p>
                <% end %>
              </div>

              <%!-- Right: Location + Map (2 cols) --%>
              <div class="lg:col-span-2">
                <%= if @primary_branch do %>
                  <.card title="Location">
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
                      <.button
                        variant="ghost"
                        size="sm"
                        icon="hero-arrow-top-right-on-square-mini"
                        href={directions_url(@primary_branch.latitude, @primary_branch.longitude)}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Get Directions
                      </.button>
                    <% end %>
                  </.card>
                <% end %>
              </div>
            </div>
          </.section>

          <%!-- Quick Stats --%>
          <.section>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <.stat_card label="Location(s)" value={length(@gym.branches)} icon="hero-map-pin" color="primary" />
              <.stat_card label="Class Types" value={length(@class_defs)} icon="hero-calendar-days" color="primary" />
              <.stat_card label="Plans" value={length(@plans)} icon="hero-credit-card" color="secondary" />
            </div>
          </.section>

          <%!-- Membership Plans --%>
          <%= if @plans != [] do %>
            <.section title="Membership Plans">
              <:actions>
                <.button variant="ghost" size="sm" navigate={"/explore/#{@gym.slug}/pricing"}>
                  View All Plans <.icon name="hero-arrow-right-mini" class="size-4" />
                </.button>
              </:actions>

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
                      <.card class={if(savings > 25, do: "ring-2 ring-primary", else: "")} padded={false}>
                        <%= if savings > 25 do %>
                          <div class="bg-gradient-to-r from-primary to-primary/80 text-primary-content text-center py-1.5 text-xs font-bold uppercase tracking-wider">
                            Best Value
                          </div>
                        <% end %>
                        <div class="p-4 text-center">
                          <h4 class="font-semibold">{PricingHelpers.duration_label(plan.duration)}</h4>
                          <p class="text-2xl font-bold text-primary mt-1">
                            Rs{PricingHelpers.format_price(plan.price_in_paise)}
                          </p>
                          <%= if months && months > 1 && per_month do %>
                            <p class="text-sm text-base-content/60">
                              Rs{PricingHelpers.format_price(per_month)}/mo
                            </p>
                            <%= if savings > 0 do %>
                              <.badge variant="success" size="sm">Save {savings}%</.badge>
                            <% end %>
                          <% end %>
                          <.button variant="primary" size="sm" navigate="/register" class="mt-3">
                            Join Now
                          </.button>
                        </div>
                      </.card>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </.section>
          <% end %>

          <%!-- Equipment & Amenities --%>
          <%= if (@gym.equipment && @gym.equipment != []) || (@gym.services && @gym.services != []) do %>
            <.section title="Equipment & Amenities">
              <div class="flex flex-wrap gap-2">
                <%= for item <- (@gym.equipment || []) ++ (@gym.services || []) do %>
                  <.badge variant="success" size="sm">
                    <.icon name="hero-check-circle-solid" class="size-3.5 mr-1" />{item}
                  </.badge>
                <% end %>
              </div>
            </.section>
          <% end %>

          <%!-- Classes & Services --%>
          <%= if @class_defs != [] do %>
            <.section title="Classes & Services">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                <%= for class_def <- @class_defs do %>
                  <.card>
                    <h4 class="font-semibold">{class_def.name}</h4>
                    <div class="flex items-center gap-2 mt-1">
                      <.badge variant="neutral" size="sm">
                        {Phoenix.Naming.humanize(class_def.class_type)}
                      </.badge>
                      <span class="text-xs text-base-content/50">
                        {class_def.default_duration_minutes} min
                      </span>
                      <%= if class_def.max_participants do %>
                        <span class="text-xs text-base-content/50">
                          · Max {class_def.max_participants}
                        </span>
                      <% end %>
                    </div>
                  </.card>
                <% end %>
              </div>
            </.section>
          <% end %>

          <%!-- Bottom CTA Banner --%>
          <.section>
            <.card>
              <div class="text-center">
                <h2 class="text-2xl font-brand mb-2">Ready to start your fitness journey?</h2>
                <p class="text-base-content/70 mb-4">
                  Join {@gym.name} today and transform your life.
                </p>
                <.button variant="primary" size="lg" icon="hero-rocket-launch-mini" navigate="/register">
                  Register Free & Join
                </.button>
              </div>
            </.card>
          </.section>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
