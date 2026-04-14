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
        <.page_header title={@gym_data.gym.name} back_path="/member/gym">
          <:actions>
            <%= if @gym_data.gym.status == :verified do %>
              <.badge variant="success">Verified</.badge>
            <% else %>
              <.badge variant="warning">{Phoenix.Naming.humanize(@gym_data.gym.status)}</.badge>
            <% end %>
            <%= if @gym_data.gym.is_promoted do %>
              <.badge variant="warning">Featured</.badge>
            <% end %>
          </:actions>
        </.page_header>

        <div class="space-y-8">
          <%!-- Quick Stats --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6">
            <.stat_card label="Location" value="1" icon="hero-map-pin" color="primary" />
            <.stat_card label="Class Types" value={length(@gym_data.class_defs)} icon="hero-calendar-days" color="warning" />
            <.stat_card label="Plans Available" value={length(@gym_data.plans)} icon="hero-credit-card" color="success" />
          </div>

          <%!-- About --%>
          <%= if @gym_data.gym.description do %>
            <.card title="About">
              <p class="text-base-content/70 whitespace-pre-wrap">{@gym_data.gym.description}</p>
            </.card>
          <% end %>

          <%!-- Your Location --%>
          <%= if @gym_data.membership.branch do %>
            <.card title="Your Location">
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
                      <.badge variant="primary" size="sm">Primary</.badge>
                    <% end %>
                  </div>
                  <p class="text-sm text-base-content/60 mt-0.5">
                    {@gym_data.membership.branch.address} -- {@gym_data.membership.branch.postal_code}
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
            </.card>
          <% end %>

          <%!-- All Locations --%>
          <%= if @gym_data.gym.branches != [] do %>
            <.card title="All Locations">
              <div class="space-y-3">
                <%= for branch <- @gym_data.gym.branches do %>
                  <div class="flex items-start gap-4 p-4 rounded-xl bg-base-200/50">
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
                          <.badge variant="primary" size="sm">Primary</.badge>
                        <% end %>
                      </div>
                      <p class="text-sm text-base-content/60 mt-0.5">
                        {branch.address} -- {branch.postal_code}
                      </p>
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
            </.card>
          <% end %>

          <%!-- Plans & Pricing --%>
          <%= if @gym_data.plans != [] do %>
            <.card title="Plans & Pricing">
              <.data_table id="plans-table" rows={@gym_data.plans}>
                <:col :let={plan} label="Plan">
                  <span class="font-semibold">{plan.name}</span>
                </:col>
                <:col :let={plan} label="Type">
                  <span class={"badge badge-xs #{plan_type_class(plan.plan_type)}"}>
                    {Phoenix.Naming.humanize(plan.plan_type)}
                  </span>
                </:col>
                <:col :let={plan} label="Duration">
                  {format_duration(plan.duration)}
                </:col>
                <:col :let={plan} label="Price">
                  <span class="font-bold text-primary">Rs {format_price(plan.price_in_paise)}</span>
                </:col>
              </.data_table>
            </.card>
          <% end %>

          <%!-- Classes & Services --%>
          <%= if @gym_data.class_defs != [] do %>
            <.card title="Classes & Services">
              <.data_table id="classes-table" rows={@gym_data.class_defs}>
                <:col :let={class_def} label="Class">
                  <span class="font-semibold">{class_def.name}</span>
                </:col>
                <:col :let={class_def} label="Type">
                  <.badge variant="neutral" size="sm">{Phoenix.Naming.humanize(class_def.class_type)}</.badge>
                </:col>
                <:col :let={class_def} label="Duration">
                  {class_def.default_duration_minutes} min
                </:col>
                <:col :let={class_def} label="Max Participants">
                  {class_def.max_participants || "--"}
                </:col>
              </.data_table>
            </.card>
          <% end %>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
