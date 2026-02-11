defmodule FitconnexWeb.Explore.GymDetailLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    case load_gym_by_slug(slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Gym not found or not yet verified.")
         |> push_navigate(to: "/explore", replace: true)}

      gym_data ->
        {:noreply,
         assign(socket,
           page_title: gym_data.gym.name,
           gym_data: gym_data
         )}
    end
  end

  defp load_gym_by_slug(slug) do
    case Fitconnex.Gym.Gym
         |> Ash.Query.filter(slug == ^slug and status == :verified)
         |> Ash.Query.load([:branches])
         |> Ash.read!() do
      [gym | _] ->
        gym_id = gym.id

        plans =
          try do
            Fitconnex.Billing.SubscriptionPlan
            |> Ash.Query.filter(gym_id == ^gym_id)
            |> Ash.read!()
            |> Enum.sort_by(& &1.price_in_paise)
          rescue
            _ -> []
          end

        class_defs =
          try do
            Fitconnex.Scheduling.ClassDefinition
            |> Ash.Query.filter(gym_id == ^gym_id)
            |> Ash.read!()
          rescue
            _ -> []
          end

        trainers =
          try do
            Fitconnex.Gym.GymTrainer
            |> Ash.Query.filter(gym_id == ^gym_id and is_active == true)
            |> Ash.read!()
          rescue
            _ -> []
          end

        all_specializations =
          trainers
          |> Enum.flat_map(& &1.specializations)
          |> Enum.uniq()
          |> Enum.sort()

        cheapest_monthly =
          plans
          |> Enum.filter(fn p -> p.duration == :monthly end)
          |> Enum.map(& &1.price_in_paise)
          |> Enum.min(fn -> nil end)

        %{
          gym: gym,
          plans: plans,
          class_defs: class_defs,
          trainers: trainers,
          trainer_count: length(trainers),
          all_specializations: all_specializations,
          cheapest_monthly: cheapest_monthly
        }

      [] ->
        nil
    end
  end

  defp format_price(paise) when is_integer(paise) do
    rupees = paise / 100
    :erlang.float_to_binary(rupees, decimals: 2)
  end

  defp format_price(_), do: "0.00"

  defp format_duration(:day_pass), do: "1 Day Pass"
  defp format_duration(:monthly), do: "1 Month"
  defp format_duration(:quarterly), do: "3 Months"
  defp format_duration(:half_yearly), do: "6 Months"
  defp format_duration(:annual), do: "12 Months"
  defp format_duration(:two_year), do: "24 Months"
  defp format_duration(other), do: Phoenix.Naming.humanize(other)

  defp plan_type_class(:general), do: "badge-primary"
  defp plan_type_class(:personal_training), do: "badge-secondary"
  defp plan_type_class(_), do: "badge-neutral"

  defp maps_url(lat, lng) when is_number(lat) and is_number(lng) do
    "https://www.google.com/maps?q=#{lat},#{lng}"
  end

  defp maps_url(_, _), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%= if assigns[:gym_data] do %>
        <div class="space-y-6">
          <%!-- Breadcrumb --%>
          <div class="text-sm breadcrumbs">
            <ul>
              <li><a href="/explore" class="text-primary">Explore Gyms</a></li>
              <li>{@gym_data.gym.name}</li>
            </ul>
          </div>

          <%!-- Hero Image / Gallery --%>
          <% primary_branch = Enum.find(@gym_data.gym.branches, & &1.is_primary) || List.first(@gym_data.gym.branches) %>
          <% all_gallery = Enum.flat_map(@gym_data.gym.branches, fn b -> b.gallery_urls || [] end) %>
          <%= if primary_branch && (primary_branch.logo_url || all_gallery != []) do %>
            <div class="rounded-lg overflow-hidden">
              <%= if primary_branch.logo_url do %>
                <img
                  src={primary_branch.logo_url}
                  alt={@gym_data.gym.name}
                  class="w-full h-48 sm:h-64 object-cover rounded-lg"
                />
              <% end %>
              <%= if all_gallery != [] do %>
                <div class="flex gap-2 mt-2 overflow-x-auto pb-2">
                  <%= for url <- Enum.take(all_gallery, 10) do %>
                    <img
                      src={url}
                      alt="Gallery"
                      class="w-24 h-24 sm:w-32 sm:h-32 rounded-lg object-cover shrink-0"
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <%!-- Header --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div class="flex items-center gap-3">
              <Layouts.back_button />
              <div>
                <div class="flex items-center gap-3 flex-wrap">
                  <h1 class="text-2xl sm:text-3xl font-black tracking-tight">{@gym_data.gym.name}</h1>
                  <span class="badge badge-sm badge-success gap-1">
                    <.icon name="hero-check-badge-mini" class="size-3" /> Verified
                  </span>
                  <%= if @gym_data.gym.is_promoted do %>
                    <span class="badge badge-sm badge-warning gap-1">
                      <.icon name="hero-star-mini" class="size-3" /> Featured
                    </span>
                  <% end %>
                </div>
                <%= if @gym_data.cheapest_monthly do %>
                  <p class="text-base-content/50 mt-1">
                    Starting at
                    <span class="font-bold text-primary">
                      Rs {format_price(@gym_data.cheapest_monthly)}/mo
                    </span>
                  </p>
                <% end %>
              </div>
            </div>
            <%= if @current_user == nil do %>
              <a href="/register" class="btn btn-primary btn-sm gap-2 font-semibold">
                <.icon name="hero-user-plus-mini" class="size-4" /> Sign Up to Join
              </a>
            <% end %>
          </div>

          <%!-- Quick Stats --%>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4 text-center">
                <div class="text-2xl font-black text-primary">{length(@gym_data.gym.branches)}</div>
                <div class="text-xs text-base-content/50">Branches</div>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4 text-center">
                <div class="text-2xl font-black text-primary">{@gym_data.trainer_count}</div>
                <div class="text-xs text-base-content/50">Trainers</div>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4 text-center">
                <div class="text-2xl font-black text-primary">{length(@gym_data.class_defs)}</div>
                <div class="text-xs text-base-content/50">Class Types</div>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4 text-center">
                <div class="text-2xl font-black text-primary">{length(@gym_data.plans)}</div>
                <div class="text-xs text-base-content/50">Plans Available</div>
              </div>
            </div>
          </div>

          <%!-- About --%>
          <%= if @gym_data.gym.description do %>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-information-circle-solid" class="size-5 text-info" /> About
                </h2>
                <p class="text-base-content/70 mt-2 whitespace-pre-wrap">
                  {@gym_data.gym.description}
                </p>
              </div>
            </div>
          <% end %>

          <%!-- Locations --%>
          <%= if @gym_data.gym.branches != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-map-pin-solid" class="size-5 text-error" /> Locations
                </h2>
                <div class="space-y-3">
                  <%= for branch <- @gym_data.gym.branches do %>
                    <div class="flex items-start gap-4 p-3 rounded-lg bg-base-300/20">
                      <%!-- Branch logo thumbnail --%>
                      <%= if branch.logo_url do %>
                        <img src={branch.logo_url} class="w-14 h-14 rounded-lg object-cover shrink-0" />
                      <% end %>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2">
                          <p class="font-semibold">{branch.city}, {branch.state}</p>
                          <%= if branch.is_primary do %>
                            <span class="badge badge-xs badge-primary">Primary</span>
                          <% end %>
                        </div>
                        <p class="text-sm text-base-content/60 mt-0.5">
                          {branch.address} — {branch.postal_code}
                        </p>
                        <%!-- Branch gallery thumbnails --%>
                        <%= if branch.gallery_urls && branch.gallery_urls != [] do %>
                          <div class="flex gap-1.5 mt-2">
                            <%= for url <- branch.gallery_urls do %>
                              <img src={url} alt="Gallery" class="w-10 h-10 rounded object-cover" />
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                      <%= if maps_url(branch.latitude, branch.longitude) do %>
                        <a
                          href={maps_url(branch.latitude, branch.longitude)}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="btn btn-outline btn-xs gap-1 shrink-0 self-center"
                        >
                          <.icon name="hero-map-pin-mini" class="size-3" /> Map
                        </a>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Plans & Pricing --%>
          <%= if @gym_data.plans != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-credit-card-solid" class="size-5 text-primary" /> Plans & Pricing
                </h2>
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Plan</th>
                        <th>Type</th>
                        <th>Duration</th>
                        <th class="text-right">Price</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for plan <- @gym_data.plans do %>
                        <tr>
                          <td class="font-semibold">{plan.name}</td>
                          <td>
                            <span class={"badge badge-xs #{plan_type_class(plan.plan_type)}"}>
                              {Phoenix.Naming.humanize(plan.plan_type)}
                            </span>
                          </td>
                          <td>{format_duration(plan.duration)}</td>
                          <td class="text-right font-bold text-primary">
                            Rs {format_price(plan.price_in_paise)}
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Classes & Services --%>
          <%= if @gym_data.class_defs != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-calendar-days-solid" class="size-5 text-warning" />
                  Classes & Services
                </h2>
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Class</th>
                        <th>Type</th>
                        <th>Duration</th>
                        <th>Max Participants</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for class_def <- @gym_data.class_defs do %>
                        <tr>
                          <td class="font-semibold">{class_def.name}</td>
                          <td>
                            <span class="badge badge-xs badge-outline">
                              {Phoenix.Naming.humanize(class_def.class_type)}
                            </span>
                          </td>
                          <td>{class_def.default_duration_minutes} min</td>
                          <td>{class_def.max_participants || "—"}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Trainer Specializations --%>
          <%= if @gym_data.all_specializations != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-academic-cap-solid" class="size-5 text-secondary" />
                  Trainer Specializations
                </h2>
                <div class="flex flex-wrap gap-2 mt-3">
                  <%= for spec <- @gym_data.all_specializations do %>
                    <span class="badge badge-outline badge-sm">{Phoenix.Naming.humanize(spec)}</span>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- CTA --%>
          <%= if @current_user == nil do %>
            <div class="card bg-primary/5 border border-primary/20">
              <div class="card-body p-6 text-center">
                <h2 class="text-lg font-bold">Interested in this gym?</h2>
                <p class="text-base-content/60 mt-1">
                  Create an account to join, book classes, and get personalized plans.
                </p>
                <div class="mt-4">
                  <a href="/register" class="btn btn-primary btn-sm gap-2">
                    <.icon name="hero-user-plus-mini" class="size-4" /> Create Free Account
                  </a>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
