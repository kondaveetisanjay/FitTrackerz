defmodule FitconnexWeb.Explore.GymListLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  alias Fitconnex.Gym.Geo

  @impl true
  def mount(_params, _session, socket) do
    gym_entries = load_verified_gyms()

    cities =
      gym_entries
      |> Enum.flat_map(fn entry -> Enum.map(entry.gym.branches, & &1.city) end)
      |> Enum.uniq()
      |> Enum.sort()

    sorted = Enum.map(gym_entries, fn entry -> {entry, nil} end)

    {:ok,
     assign(socket,
       page_title: "Explore Gyms",
       all_entries: gym_entries,
       sorted_entries: sorted,
       cities: cities,
       search_query: "",
       city_filter: "",
       user_lat: nil,
       user_lng: nil,
       place_name: nil
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

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(search_query: "", city_filter: "")
     |> apply_filters()}
  end

  def handle_event("set_location", %{"latitude" => lat, "longitude" => lng}, socket) do
    place_name =
      case Fitconnex.Gym.ReverseGeocode.reverse_geocode(lat, lng) do
        {:ok, name} -> name
        {:error, _} -> ""
      end

    {:noreply,
     socket
     |> assign(user_lat: lat, user_lng: lng, place_name: place_name)
     |> apply_filters()}
  end

  def handle_event("location_error", _params, socket) do
    {:noreply,
     put_flash(socket, :error, "Could not detect your location. Please allow location access.")}
  end

  defp apply_filters(socket) do
    %{
      all_entries: all_entries,
      search_query: query,
      city_filter: city,
      user_lat: lat,
      user_lng: lng
    } = socket.assigns

    filtered =
      all_entries
      |> maybe_filter_search(query)
      |> maybe_filter_city(city)

    sorted = Geo.sort_by_nearest(filtered, lat, lng)

    assign(socket, sorted_entries: sorted)
  end

  defp maybe_filter_search(entries, ""), do: entries

  defp maybe_filter_search(entries, query) do
    q = String.downcase(query)

    Enum.filter(entries, fn entry ->
      String.contains?(String.downcase(entry.gym.name), q)
    end)
  end

  defp maybe_filter_city(entries, ""), do: entries

  defp maybe_filter_city(entries, city) do
    Enum.filter(entries, fn entry ->
      Enum.any?(entry.gym.branches, fn branch -> branch.city == city end)
    end)
  end

  defp load_verified_gyms do
    gyms =
      Fitconnex.Gym.Gym
      |> Ash.Query.filter(status == :verified)
      |> Ash.Query.load([:branches])
      |> Ash.read!()

    Enum.map(gyms, fn gym ->
      gym_id = gym.id

      plans =
        try do
          Fitconnex.Billing.SubscriptionPlan
          |> Ash.Query.filter(gym_id == ^gym_id)
          |> Ash.read!()
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

      trainer_count =
        try do
          Fitconnex.Gym.GymTrainer
          |> Ash.Query.filter(gym_id == ^gym_id)
          |> Ash.Query.filter(is_active == true)
          |> Ash.read!()
          |> length()
        rescue
          _ -> 0
        end

      %{
        gym: gym,
        plans: plans,
        class_defs: class_defs,
        trainer_count: trainer_count,
        cheapest_monthly: cheapest_monthly_price(plans),
        class_types: class_defs |> Enum.map(& &1.class_type) |> Enum.uniq() |> Enum.sort(),
        primary_city: primary_city(gym.branches)
      }
    end)
    |> Enum.sort_by(fn entry -> if entry.gym.is_promoted, do: 0, else: 1 end)
  end

  defp cheapest_monthly_price(plans) do
    plans
    |> Enum.filter(fn p -> p.duration == :monthly end)
    |> Enum.map(& &1.price_in_paise)
    |> Enum.min(fn -> nil end)
  end

  defp primary_city(branches) do
    case Enum.find(branches, fn b -> b.is_primary end) do
      nil -> if branches != [], do: hd(branches).city, else: nil
      branch -> branch.city
    end
  end

  defp format_price(nil), do: nil

  defp format_price(paise) when is_integer(paise) do
    rupees = paise / 100
    :erlang.float_to_binary(rupees, decimals: 2)
  end

  defp format_price(_), do: nil

  defp format_distance(nil), do: nil

  defp format_distance(km) when km < 1 do
    meters = round(km * 1000)
    "#{meters} m"
  end

  defp format_distance(km) do
    "#{:erlang.float_to_binary(km * 1.0, decimals: 1)} km"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Page Header --%>
        <div>
          <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Explore Gyms</h1>
          <p class="text-base-content/50 mt-1">
            Discover gyms near you, compare prices & services — all in one place.
          </p>
        </div>

        <%!-- Search & Filters Bar --%>
        <div class="card bg-base-200/50 border border-base-300/50">
          <div class="card-body p-4">
            <div class="flex flex-col sm:flex-row gap-3">
              <%!-- Search --%>
              <div class="flex-1">
                <form phx-change="search" phx-submit="search">
                  <label class="input input-bordered input-sm flex items-center gap-2 w-full">
                    <.icon name="hero-magnifying-glass-mini" class="size-4 opacity-50" />
                    <input
                      type="text"
                      name="query"
                      value={@search_query}
                      placeholder="Search gyms by name..."
                      class="grow"
                      phx-debounce="300"
                    />
                  </label>
                </form>
              </div>

              <%!-- City Filter --%>
              <div class="w-full sm:w-48">
                <form phx-change="filter_city">
                  <select name="city" class="select select-bordered select-sm w-full">
                    <option value="">All Cities</option>
                    <%= for city <- @cities do %>
                      <option value={city} selected={@city_filter == city}>{city}</option>
                    <% end %>
                  </select>
                </form>
              </div>

              <%!-- Location Button --%>
              <button
                id="detect-location-btn"
                phx-hook="Geolocation"
                class={"btn btn-sm gap-2 #{if @user_lat, do: "btn-success", else: "btn-outline"}"}
              >
                <.icon name="hero-map-pin-mini" class="size-4" />
                <%= if @user_lat do %>
                  Location detected
                <% else %>
                  Detect my location
                <% end %>
              </button>

              <%!-- Clear Filters --%>
              <%= if @search_query != "" or @city_filter != "" do %>
                <button phx-click="clear_filters" class="btn btn-ghost btn-sm gap-1">
                  <.icon name="hero-x-mark-mini" class="size-4" /> Clear
                </button>
              <% end %>
            </div>

            <%!-- Location Info --%>
            <%= if @user_lat do %>
              <div class="flex items-center gap-2 mt-2 pt-2 border-t border-base-300/30">
                <.icon name="hero-map-pin-solid" class="size-4 text-success shrink-0" />
                <span class="text-sm text-base-content/60">
                  Your location:
                  <span class="font-semibold text-base-content/80">
                    {@place_name}
                  </span>
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Results Count --%>
        <div class="flex items-center justify-between">
          <p class="text-sm text-base-content/50">
            {length(@sorted_entries)} gym(s) found
            <%= if @user_lat do %>
              <span class="badge badge-sm badge-success gap-1 ml-2">
                <.icon name="hero-map-pin-mini" class="size-3" /> Sorted by distance
              </span>
            <% end %>
          </p>
        </div>

        <%!-- Gym Cards Grid --%>
        <%= if @sorted_entries == [] do %>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-8 text-center">
              <.icon name="hero-building-office-2-solid" class="size-16 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gyms Found</h2>
              <p class="text-base-content/50 mt-1">
                <%= if @search_query != "" or @city_filter != "" do %>
                  Try adjusting your search or filters.
                <% else %>
                  No verified gyms are available yet. Check back soon!
                <% end %>
              </p>
            </div>
          </div>
        <% else %>
          <div class="flex flex-col gap-3" id="gym-list">
            <%= for {entry, distance} <- @sorted_entries do %>
              <a
                href={"/explore/#{entry.gym.slug}"}
                class="flex items-center gap-4 p-4 rounded-lg bg-base-200/50 border border-base-300/50 hover:border-primary/30 hover:shadow-lg transition-all cursor-pointer"
                id={"gym-card-#{entry.gym.id}"}
              >
                <%!-- Gym Icon --%>
                <div class="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                  <.icon name="hero-building-office-2-solid" class="size-6 text-primary" />
                </div>

                <%!-- Name & City --%>
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2">
                    <h3 class="text-base font-bold truncate">{entry.gym.name}</h3>
                    <%= if entry.gym.is_promoted do %>
                      <span class="badge badge-xs badge-warning gap-1">
                        <.icon name="hero-star-mini" class="size-2.5" /> Featured
                      </span>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-3 mt-0.5 text-sm text-base-content/50">
                    <%= if entry.primary_city do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-map-pin-mini" class="size-3.5" />
                        {entry.primary_city}
                      </span>
                    <% end %>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-map-pin-mini" class="size-3.5" />
                      {length(entry.gym.branches)} branch(es)
                    </span>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-academic-cap-mini" class="size-3.5" />
                      {entry.trainer_count} trainer(s)
                    </span>
                  </div>
                </div>

                <%!-- Distance Badge --%>
                <%= if distance do %>
                  <span class="badge badge-sm badge-info shrink-0">{format_distance(distance)}</span>
                <% end %>

                <%!-- Price --%>
                <div class="text-right shrink-0">
                  <%= if format_price(entry.cheapest_monthly) do %>
                    <span class="text-lg font-black text-primary">
                      Rs {format_price(entry.cheapest_monthly)}
                    </span>
                    <span class="text-xs text-base-content/50">/mo</span>
                  <% else %>
                    <span class="text-sm text-base-content/40">Contact for pricing</span>
                  <% end %>
                </div>

                <%!-- Arrow --%>
                <.icon name="hero-chevron-right-mini" class="size-5 text-base-content/30 shrink-0" />
              </a>
            <% end %>
          </div>
        <% end %>

        <%!-- Sign Up CTA --%>
        <%= if @current_user == nil do %>
          <div class="card bg-primary/5 border border-primary/20">
            <div class="card-body p-6 text-center">
              <h2 class="text-lg font-bold">Ready to start your fitness journey?</h2>
              <p class="text-base-content/60 mt-1">
                Sign up to join a gym, book classes, and track your progress.
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
    </Layouts.app>
    """
  end
end
