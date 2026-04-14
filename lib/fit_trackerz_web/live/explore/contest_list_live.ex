defmodule FitTrackerzWeb.Explore.ContestListLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    contests = load_contests(actor)

    cities =
      contests
      |> Enum.map(& &1.city)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    contest_types = [:challenge, :competition, :event, :other]

    {:ok,
     assign(socket,
       page_title: "Fitness Contests",
       all_contests: contests,
       filtered_contests: contests,
       cities: cities,
       contest_types: contest_types,
       search_query: "",
       city_filter: "",
       type_filter: "",
       status_filter: ""
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(search_query: query)
     |> apply_filters()}
  end

  def handle_event("filter_city", %{"city" => city}, socket) do
    {:noreply,
     socket
     |> assign(city_filter: city)
     |> apply_filters()}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(type_filter: type)
     |> apply_filters()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(status_filter: status)
     |> apply_filters()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(search_query: "", city_filter: "", type_filter: "", status_filter: "")
     |> apply_filters()}
  end

  # -- Private --

  defp load_contests(actor) do
    read_actor = actor || FitTrackerz.Accounts.SystemActor.system_actor()
    opts = [actor: read_actor]

    contests =
      FitTrackerz.Gym.Contest
      |> Ash.Query.for_read(:list_public, %{}, opts)
      |> Ash.read!(opts)

    Enum.map(contests, fn contest ->
      gym = contest.gym

      branches =
        FitTrackerz.Gym.GymBranch
        |> Ash.Query.for_read(:list_by_gym, %{gym_id: gym.id}, opts)
        |> Ash.read!(opts)

      primary_city =
        case Enum.find(branches, & &1.is_primary) || List.first(branches) do
          nil -> nil
          branch -> branch.city
        end

      %{
        contest: contest,
        gym_name: gym.name,
        gym_slug: gym.slug,
        city: primary_city
      }
    end)
  end

  defp apply_filters(socket) do
    filtered =
      socket.assigns.all_contests
      |> filter_by_search(socket.assigns.search_query)
      |> filter_by_city(socket.assigns.city_filter)
      |> filter_by_type(socket.assigns.type_filter)
      |> filter_by_status(socket.assigns.status_filter)

    assign(socket, filtered_contests: filtered)
  end

  defp filter_by_search(contests, ""), do: contests

  defp filter_by_search(contests, query) do
    q = String.downcase(query)

    Enum.filter(contests, fn e ->
      String.contains?(String.downcase(e.contest.title), q) or
        String.contains?(String.downcase(e.gym_name), q)
    end)
  end

  defp filter_by_city(contests, ""), do: contests
  defp filter_by_city(contests, city), do: Enum.filter(contests, &(&1.city == city))

  defp filter_by_type(contests, ""), do: contests

  defp filter_by_type(contests, type) do
    type_atom = String.to_existing_atom(type)
    Enum.filter(contests, &(&1.contest.contest_type == type_atom))
  end

  defp filter_by_status(contests, ""), do: contests

  defp filter_by_status(contests, status) do
    status_atom = String.to_existing_atom(status)
    Enum.filter(contests, &(&1.contest.status == status_atom))
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp type_badge_variant(:challenge), do: "warning"
  defp type_badge_variant(:competition), do: "error"
  defp type_badge_variant(:event), do: "info"
  defp type_badge_variant(_), do: "neutral"

  defp status_badge_variant(:upcoming), do: "info"
  defp status_badge_variant(:active), do: "success"
  defp status_badge_variant(:completed), do: "neutral"
  defp status_badge_variant(:cancelled), do: "error"
  defp status_badge_variant(_), do: "neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Breadcrumb --%>
        <div class="flex items-center gap-2 mb-1">
          <a href="/explore" class="text-base-content/50 hover:text-primary text-sm">Explore</a>
          <span class="text-base-content/30">/</span>
          <span class="text-sm font-medium">Contests</span>
        </div>

        <.page_header title="Fitness Contests" subtitle="Discover challenges, competitions & events at gyms near you.">
          <:actions>
            <%= if @current_user && to_string(@current_user.role) == "gym_operator" do %>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/contests">
                Manage Contests
              </.button>
            <% end %>
          </:actions>
        </.page_header>

        <%!-- Search & Filters --%>
        <.card>
          <div class="flex flex-col sm:flex-row gap-3">
            <%!-- Search --%>
            <div class="flex-1">
              <form phx-change="search" phx-submit="search">
                <label class="input input-bordered flex items-center gap-2 w-full">
                  <.icon name="hero-magnifying-glass-mini" class="size-4 opacity-50" />
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search contests or gym names..."
                    class="grow"
                    phx-debounce="300"
                  />
                </label>
              </form>
            </div>

            <%!-- City Filter --%>
            <div class="w-full sm:w-40">
              <form phx-change="filter_city">
                <select name="city" class="select select-bordered w-full">
                  <option value="">All Cities</option>
                  <%= for city <- @cities do %>
                    <option value={city} selected={@city_filter == city}>{city}</option>
                  <% end %>
                </select>
              </form>
            </div>

            <%!-- Type Filter --%>
            <div class="w-full sm:w-40">
              <form phx-change="filter_type">
                <select name="type" class="select select-bordered w-full">
                  <option value="">All Types</option>
                  <%= for type <- @contest_types do %>
                    <option value={type} selected={@type_filter == to_string(type)}>
                      {type |> to_string() |> String.capitalize()}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <%!-- Status Filter --%>
            <div class="w-full sm:w-40">
              <form phx-change="filter_status">
                <select name="status" class="select select-bordered w-full">
                  <option value="">All Statuses</option>
                  <option value="upcoming" selected={@status_filter == "upcoming"}>Upcoming</option>
                  <option value="active" selected={@status_filter == "active"}>Active</option>
                </select>
              </form>
            </div>

            <%!-- Clear --%>
            <%= if @search_query != "" or @city_filter != "" or @type_filter != "" or @status_filter != "" do %>
              <.button variant="ghost" size="sm" icon="hero-x-mark-mini" phx-click="clear_filters">
                Clear
              </.button>
            <% end %>
          </div>
        </.card>

        <%!-- Results Count --%>
        <p class="text-sm text-base-content/50">
          {length(@filtered_contests)} contest(s) found
        </p>

        <%!-- Contest Cards --%>
        <%= if @filtered_contests == [] do %>
          <.card>
            <.empty_state
              icon="hero-trophy"
              title="No Contests Found"
              subtitle={
                if @search_query != "" or @city_filter != "" or @type_filter != "",
                  do: "Try adjusting your search or filters.",
                  else: "No contests are currently available. Check back soon!"
              }
            >
              <:action>
                <%= if @search_query != "" or @city_filter != "" or @type_filter != "" or @status_filter != "" do %>
                  <.button variant="ghost" size="sm" icon="hero-x-mark-mini" phx-click="clear_filters">
                    Clear Filters
                  </.button>
                <% end %>
              </:action>
            </.empty_state>
          </.card>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for entry <- @filtered_contests do %>
              <div id={"contest-card-#{entry.contest.id}"}>
              <.card padded={false} class="hover:shadow-lg hover:-translate-y-0.5 transition-all">
                <%!-- Banner --%>
                <figure class="h-36 bg-base-300/30 overflow-hidden">
                  <%= if entry.contest.banner_url do %>
                    <img
                      src={entry.contest.banner_url}
                      alt={entry.contest.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center">
                      <.icon name="hero-trophy-solid" class="size-12 text-base-content/10" />
                    </div>
                  <% end %>
                </figure>

                <div class="p-4 space-y-3">
                  <%!-- Badges --%>
                  <div class="flex flex-wrap gap-1.5">
                    <.badge variant={type_badge_variant(entry.contest.contest_type)} size="sm">
                      {entry.contest.contest_type |> to_string() |> String.capitalize()}
                    </.badge>
                    <.badge variant={status_badge_variant(entry.contest.status)} size="sm">
                      {entry.contest.status |> to_string() |> String.capitalize()}
                    </.badge>
                  </div>

                  <%!-- Title --%>
                  <h2 class="text-lg font-semibold leading-tight">{entry.contest.title}</h2>

                  <%!-- Description --%>
                  <%= if entry.contest.description do %>
                    <p class="text-sm text-base-content/60 line-clamp-2">{entry.contest.description}</p>
                  <% end %>

                  <%!-- Gym & Location --%>
                  <div class="flex flex-col gap-1 text-sm text-base-content/60">
                    <div class="flex items-center gap-1.5">
                      <.icon name="hero-building-office-2-mini" class="size-3.5 shrink-0" />
                      <a href={"/explore/#{entry.gym_slug}"} class="hover:text-primary truncate">
                        {entry.gym_name}
                      </a>
                    </div>
                    <%= if entry.city do %>
                      <div class="flex items-center gap-1.5">
                        <.icon name="hero-map-pin-mini" class="size-3.5 shrink-0" />
                        <span class="truncate">{entry.city}</span>
                      </div>
                    <% end %>
                  </div>

                  <%!-- Dates --%>
                  <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                    <.icon name="hero-calendar-mini" class="size-3.5 shrink-0" />
                    <span>{format_date(entry.contest.starts_at)} — {format_date(entry.contest.ends_at)}</span>
                  </div>

                  <%!-- Participants --%>
                  <%= if entry.contest.max_participants do %>
                    <div class="flex items-center gap-1.5 text-sm text-base-content/60">
                      <.icon name="hero-users-mini" class="size-3.5 shrink-0" />
                      <span>{entry.contest.max_participants} max participants</span>
                    </div>
                  <% end %>

                  <%!-- Prize --%>
                  <%= if entry.contest.prize_description do %>
                    <div class="flex items-start gap-1.5 text-sm text-base-content/60">
                      <.icon name="hero-gift-mini" class="size-3.5 shrink-0 mt-0.5" />
                      <span class="line-clamp-2">{entry.contest.prize_description}</span>
                    </div>
                  <% end %>
                </div>
              </.card>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- CTA for unauthenticated --%>
        <%= unless @current_user do %>
          <.card>
            <div class="text-center">
              <h3 class="font-bold text-lg">Want to compete?</h3>
              <p class="text-base-content/60 text-sm mt-1">
                Create an account to register for contests and track your fitness journey.
              </p>
              <div class="mt-3">
                <.button variant="primary" size="sm" navigate="/register">Create an Account</.button>
              </div>
            </div>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
