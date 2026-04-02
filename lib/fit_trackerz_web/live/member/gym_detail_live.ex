defmodule FitTrackerzWeb.Member.GymDetailLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    actor = socket.assigns.current_user

    # Verify the member belongs to this gym
    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:branch]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    membership = Enum.find(memberships, &(&1.gym_id == id))

    if membership == nil do
      {:noreply,
       socket
       |> put_flash(:error, "You are not a member of this gym.")
       |> push_navigate(to: "/member/gym", replace: true)}
    else
      case load_gym_data(id, membership) do
        nil ->
          {:noreply,
           socket
           |> put_flash(:error, "Gym not found.")
           |> push_navigate(to: "/member/gym", replace: true)}

        gym_data ->
          {:noreply,
           assign(socket,
             page_title: gym_data.gym.name,
             gym_data: gym_data
           )}
      end
    end
  end

  defp load_gym_data(gym_id, membership) do
    actor = membership

    case FitTrackerz.Gym.get_gym(gym_id, actor: actor, load: [:branches]) do
      {:ok, gym} ->
        plans = case FitTrackerz.Billing.list_plans_by_gym(gym_id, actor: actor) do
          {:ok, plans} -> Enum.sort_by(plans, & &1.price_in_paise)
          _ -> []
        end

        class_defs = case FitTrackerz.Scheduling.list_class_definitions_by_gym(gym_id, actor: actor) do
          {:ok, defs} -> defs
          _ -> []
        end

        %{
          gym: gym,
          membership: membership,
          plans: plans,
          class_defs: class_defs
        }

      _ ->
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
          <%!-- Header --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div class="flex items-center gap-3">
              <.link navigate="/member/gym" class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-arrow-left-mini" class="size-5" />
              </.link>

              <div>
                <div class="flex items-center gap-3 flex-wrap">
                  <h1 class="text-2xl sm:text-3xl font-brand">
                    {@gym_data.gym.name}
                  </h1>

                  <%= if @gym_data.gym.status == :verified do %>
                    <span class="badge badge-sm badge-success gap-1">
                      <.icon name="hero-check-badge-mini" class="size-3" /> Verified
                    </span>
                  <% else %>
                    <span class="badge badge-sm badge-warning gap-1">
                      {Phoenix.Naming.humanize(@gym_data.gym.status)}
                    </span>
                  <% end %>

                  <%= if @gym_data.gym.is_promoted do %>
                    <span class="badge badge-sm badge-warning gap-1">
                      <.icon name="hero-star-mini" class="size-3" /> Featured
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Quick Stats --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="ft-card p-6">
              <div class="text-center">
                <div class="text-2xl font-black text-primary">1</div>
                <div class="text-xs text-base-content/50">Location</div>
              </div>
            </div>

            <div class="ft-card p-6">
              <div class="text-center">
                <div class="text-2xl font-black text-primary">{length(@gym_data.class_defs)}</div>
                <div class="text-xs text-base-content/50">Class Types</div>
              </div>
            </div>

            <div class="ft-card p-6">
              <div class="text-center">
                <div class="text-2xl font-black text-primary">{length(@gym_data.plans)}</div>
                <div class="text-xs text-base-content/50">Plans Available</div>
              </div>
            </div>
          </div>

          <%!-- About --%>
          <%= if @gym_data.gym.description do %>
            <div class="ft-card p-6">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-information-circle-solid" class="size-5 text-info" /> About
              </h2>
              <p class="text-base-content/70 mt-2 whitespace-pre-wrap">
                {@gym_data.gym.description}
              </p>
            </div>
          <% end %>

          <%!-- Your Location --%>
          <%= if @gym_data.membership.branch do %>
            <div class="ft-card p-6 border border-primary/20">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-map-pin-solid" class="size-5 text-primary" /> Your Location
              </h2>

              <div class="flex items-start gap-4 p-4 rounded-xl bg-primary/5 border border-primary/20">
                <%= if @gym_data.membership.branch.logo_url do %>
                  <img
                    src={@gym_data.membership.branch.logo_url}
                    class="w-14 h-14 rounded-lg object-cover shrink-0"
                  />
                <% end %>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <p class="font-semibold">
                      {@gym_data.membership.branch.city}, {@gym_data.membership.branch.state}
                    </p>

                    <%= if @gym_data.membership.branch.is_primary do %>
                      <span class="badge badge-xs badge-primary">Primary</span>
                    <% end %>
                  </div>

                  <p class="text-sm text-base-content/60 mt-0.5">
                    {@gym_data.membership.branch.address} — {@gym_data.membership.branch.postal_code}
                  </p>
                </div>

                <%= if maps_url(@gym_data.membership.branch.latitude, @gym_data.membership.branch.longitude) do %>
                  <a
                    href={maps_url(@gym_data.membership.branch.latitude, @gym_data.membership.branch.longitude)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="btn btn-outline btn-xs gap-1 shrink-0 self-center"
                  >
                    <.icon name="hero-map-pin-mini" class="size-3" /> Map
                  </a>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- All Locations --%>
          <%= if @gym_data.gym.branches != [] do %>
            <div class="ft-card p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-map-pin-solid" class="size-5 text-error" /> Location
              </h2>

              <div class="space-y-3">
                <%= for branch <- @gym_data.gym.branches do %>
                  <div class="flex items-start gap-4 p-3 bg-base-200/30 rounded-xl">
                    <%= if branch.logo_url do %>
                      <img
                        src={branch.logo_url}
                        class="w-14 h-14 rounded-lg object-cover shrink-0"
                      />
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

                      <%= if branch.gallery_urls && branch.gallery_urls != [] do %>
                        <div class="flex gap-1.5 mt-2">
                          <%= for url <- branch.gallery_urls do %>
                            <img
                              src={url}
                              alt="Gallery"
                              class="w-10 h-10 rounded object-cover"
                            />
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
          <% end %>

          <%!-- Plans & Pricing --%>
          <%= if @gym_data.plans != [] do %>
            <div class="ft-card p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-credit-card-solid" class="size-5 text-primary" />
                Plans & Pricing
              </h2>

              <div class="ft-table overflow-x-auto">
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
          <% end %>

          <%!-- Classes & Services --%>
          <%= if @gym_data.class_defs != [] do %>
            <div class="ft-card p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-calendar-days-solid" class="size-5 text-warning" />
                Classes & Services
              </h2>

              <div class="ft-table overflow-x-auto">
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
          <% end %>

        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
