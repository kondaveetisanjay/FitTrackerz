defmodule FitTrackerzWeb.Explore.GymListLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Gym.Geo

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    gym_entries = load_verified_gyms(actor)

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
       place_name: nil,
       sort_by: "distance",
       page: 1,
       per_page: 9
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
     |> assign(search_query: "", city_filter: "", user_lat: nil, user_lng: nil, place_name: nil)
     |> apply_filters()}
  end

  def handle_event("place_selected", %{"latitude" => lat, "longitude" => lng} = params, socket) do
    place_name = params["place_name"] || ""
    city = params["city"] || ""

    city_filter =
      if city != "" and city in socket.assigns.cities do
        city
      else
        socket.assigns.city_filter
      end

    {:noreply,
     socket
     |> assign(user_lat: lat, user_lng: lng, place_name: place_name, city_filter: city_filter)
     |> apply_filters()}
  end

  def handle_event("set_location", %{"latitude" => lat, "longitude" => lng}, socket) do
    place_name =
      case FitTrackerz.Gym.ReverseGeocode.reverse_geocode(lat, lng) do
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

  def handle_event("sort", %{"sort" => sort_by}, socket) do
    {:noreply,
     socket
     |> assign(sort_by: sort_by, page: 1)
     |> apply_filters()}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, assign(socket, :page, String.to_integer(page))}
  end

  defp apply_filters(socket) do
    %{
      all_entries: all_entries,
      search_query: query,
      city_filter: city,
      user_lat: lat,
      user_lng: lng,
      sort_by: sort_by
    } = socket.assigns

    filtered =
      all_entries
      |> maybe_filter_search(query)
      |> maybe_filter_city(city)

    sorted = sort_entries(filtered, sort_by, lat, lng)

    assign(socket, sorted_entries: sorted, page: 1)
  end

  defp sort_entries(entries, "distance", lat, lng) do
    Geo.sort_by_nearest(entries, lat, lng)
  end

  defp sort_entries(entries, "price_low", _lat, _lng) do
    Enum.map(entries, fn entry -> {entry, nil} end)
    |> Enum.sort_by(fn {entry, _} -> entry.cheapest_monthly || 999_999_999 end, :asc)
  end

  defp sort_entries(entries, "price_high", _lat, _lng) do
    Enum.map(entries, fn entry -> {entry, nil} end)
    |> Enum.sort_by(fn {entry, _} -> entry.cheapest_monthly || 0 end, :desc)
  end

  defp sort_entries(entries, _default, lat, lng) do
    Geo.sort_by_nearest(entries, lat, lng)
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

  defp load_verified_gyms(actor) do
    gyms =
      case FitTrackerz.Gym.list_verified_gyms(actor: actor) do
        {:ok, result} -> result
        {:error, _} -> []
      end

    Enum.map(gyms, fn gym ->
      gym_id = gym.id

      plans =
        case FitTrackerz.Billing.list_plans_by_gym(gym_id, actor: actor) do
          {:ok, result} -> result
          {:error, _} -> []
        end

      class_defs =
        case FitTrackerz.Scheduling.list_class_definitions_by_gym(gym_id, actor: actor) do
          {:ok, result} -> result
          {:error, _} -> []
        end

      %{
        gym: gym,
        plans: plans,
        class_defs: class_defs,
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

  defp branch_logo(entry) do
    branches = entry.gym.branches
    primary = Enum.find(branches, & &1.is_primary) || List.first(branches)
    if primary, do: primary.logo_url, else: nil
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
        <%!-- Page Header (hero with glow) --%>
        <div class="surface-3 accent-top relative overflow-hidden reveal">
          <div class="pointer-events-none absolute -top-16 -right-16 w-56 h-56 rounded-full bg-primary/25 blur-3xl"></div>
          <div class="pointer-events-none absolute -bottom-20 -left-12 w-48 h-48 rounded-full bg-secondary/20 blur-3xl"></div>
          <div class="relative p-6 sm:p-8">
            <h1 class="text-3xl sm:text-4xl font-brand text-gradient-brand">Explore Gyms</h1>
            <p class="text-base text-base-content/60 mt-2">
              Discover gyms near you, compare prices &amp; services — all in one place.
            </p>
          </div>
        </div>

        <%!-- Location Hint --%>
        <%= unless @user_lat do %>
          <div class="flex items-center gap-2 px-4 py-2.5 rounded-lg bg-info/10 border border-info/20">
            <.icon name="hero-map-pin-mini" class="size-4 text-info shrink-0" />
            <p class="text-base text-base-content/70">
              Tap <span class="font-semibold text-info">"Detect my location"</span> to find the nearest and best gyms around you.
            </p>
          </div>
        <% end %>

        <%!-- Search & Filters Bar --%>
        <div class="glass-card reveal">
          <div class="card-body p-4">
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
                  <select name="city" class="select select-bordered w-full">
                    <option value="">All Locations</option>
                    <%= for city <- @cities do %>
                      <option value={city} selected={@city_filter == city}>{city}</option>
                    <% end %>
                  </select>
                </form>
              </div>

              <%!-- Sort --%>
              <div class="w-full sm:w-48">
                <form phx-change="sort">
                  <select name="sort" class="select select-bordered w-full">
                    <option value="distance" selected={@sort_by == "distance"}>Nearest</option>
                    <option value="price_low" selected={@sort_by == "price_low"}>Price: Low to High</option>
                    <option value="price_high" selected={@sort_by == "price_high"}>Price: High to Low</option>
                  </select>
                </form>
              </div>

              <%!-- Clear Filters --%>
              <%= if @search_query != "" or @city_filter != "" or @user_lat do %>
                <button phx-click="clear_filters" class="btn btn-ghost btn-sm gap-1">
                  <.icon name="hero-x-mark-mini" class="size-4" /> Clear
                </button>
              <% end %>
            </div>

            <%!-- Location Search with Google Places Autocomplete --%>
            <div class="flex flex-col sm:flex-row gap-3 mt-3 pt-3 border-t border-base-300/30">
              <div class="flex-1" id="explore-place-wrapper" phx-update="ignore">
                <label class="input input-bordered flex items-center gap-2 w-full">
                  <.icon name="hero-map-pin-mini" class="size-4 text-primary opacity-70" />
                  <input
                    type="text"
                    id="explore-place-search"
                    phx-hook="ExplorePlacesAutocomplete"
                    placeholder="Type a location to find nearby gyms..."
                    class="grow"
                    autocomplete="off"
                  />
                </label>
              </div>
              <span class="text-xs text-base-content/40 self-center hidden sm:block">or</span>
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
          <p class="text-base text-base-content/50">
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
          <div class="glass-card relative">
            <div class="card-body p-8 text-center">
              <.icon name="hero-building-office-2-solid" class="size-16 text-base-content/20 mx-auto" />
              <div class="absolute top-6 right-6 w-16 h-16 border-2 border-primary/10 rounded-full"></div>
              <div class="absolute bottom-6 left-6 w-12 h-12 border-2 border-secondary/10 rounded-lg rotate-45"></div>
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
          <% page_entries = @sorted_entries |> Enum.drop((@page - 1) * @per_page) |> Enum.take(@per_page) %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" id="gym-list" phx-hook="StaggerChildren" data-stagger="60">
            <%= for {entry, distance} <- page_entries do %>
              <a
                href={"/explore/#{entry.gym.slug}"}
                class="glass-card accent-top cursor-pointer overflow-hidden group hover-lift hover-img-zoom reveal block"
                id={"gym-card-#{entry.gym.id}"}
              >
                <%!-- Image --%>
                <figure class="h-40 bg-base-300/30 overflow-hidden">
                  <%= if branch_logo(entry) do %>
                    <img
                      src={branch_logo(entry)}
                      alt={entry.gym.name}
                      class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary/10 via-base-200 to-secondary/5 relative overflow-hidden">
                      <div class="absolute top-3 right-3 w-16 h-16 border-2 border-primary/10 rounded-full"></div>
                      <div class="absolute bottom-3 left-3 w-10 h-10 border-2 border-secondary/10 rounded-lg rotate-45"></div>
                      <div class="text-center">
                        <div class="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center mx-auto border border-primary/15">
                          <.icon name="hero-building-office-2-solid" class="size-7 text-primary/40" />
                        </div>
                      </div>
                    </div>
                  <% end %>
                </figure>

                <%!-- Content --%>
                <div class="card-body p-4 gap-2">
                  <%!-- Name + Badges --%>
                  <div class="flex items-start justify-between gap-2">
                    <h3 class="card-title text-lg truncate">{entry.gym.name}</h3>
                    <%= if entry.gym.is_promoted do %>
                      <span class="badge badge-xs badge-glow-warning gap-1 shrink-0">
                        <.icon name="hero-star-mini" class="size-2.5" /> Featured
                      </span>
                    <% end %>
                  </div>

                  <%!-- Location & Stats --%>
                  <div class="flex items-center gap-2 text-sm text-base-content/50 flex-wrap">
                    <%= if entry.primary_city do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-map-pin-mini" class="size-3.5" />
                        {entry.primary_city}
                      </span>
                    <% end %>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-building-office-2-mini" class="size-3.5" />
                      1 location
                    </span>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-calendar-days-mini" class="size-3.5" />
                      {length(entry.class_defs)} class type(s)
                    </span>
                  </div>

                  <%!-- Price + Distance --%>
                  <div class="flex items-center justify-between mt-1 pt-3 border-t border-primary/10">
                    <div>
                      <%= if format_price(entry.cheapest_monthly) do %>
                        <span class="text-xl font-black text-gradient-brand">
                          Rs {format_price(entry.cheapest_monthly)}
                        </span>
                        <span class="text-sm text-base-content/40">/mo</span>
                      <% else %>
                        <span class="text-base text-base-content/40">Contact for pricing</span>
                      <% end %>
                    </div>
                    <%= if distance do %>
                      <span class="badge badge-sm badge-glow-primary gap-1">
                        <.icon name="hero-map-pin-mini" class="size-3" />
                        {format_distance(distance)}
                      </span>
                    <% end %>
                  </div>

                  <%!-- Service Tags --%>
                  <%= if entry.gym.services && entry.gym.services != [] do %>
                    <div class="flex flex-wrap gap-1 mt-2">
                      <%= for service <- Enum.take(entry.gym.services, 3) do %>
                        <span class="badge badge-outline badge-xs">{service}</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </a>
            <% end %>
          </div>
        <% end %>

        <%!-- Pagination --%>
        <% total_pages = max(ceil(length(@sorted_entries) / @per_page), 1) %>
        <%= if total_pages > 1 do %>
          <div class="flex justify-center gap-2 mt-8">
            <button
              phx-click="change_page"
              phx-value-page={max(@page - 1, 1)}
              class="btn btn-sm btn-ghost"
              disabled={@page == 1}
            >
              <.icon name="hero-chevron-left-mini" class="size-4" /> Previous
            </button>
            <%= for p <- 1..total_pages do %>
              <button
                phx-click="change_page"
                phx-value-page={p}
                class={["btn btn-sm", if(p == @page, do: "btn-primary", else: "btn-ghost")]}
              >
                {p}
              </button>
            <% end %>
            <button
              phx-click="change_page"
              phx-value-page={min(@page + 1, total_pages)}
              class="btn btn-sm btn-ghost"
              disabled={@page == total_pages}
            >
              Next <.icon name="hero-chevron-right-mini" class="size-4" />
            </button>
          </div>
        <% end %>

        <%!-- Sign Up CTA --%>
        <%= if @current_user == nil do %>
          <div class="surface-3 accent-top mt-6 relative overflow-hidden">
            <div class="pointer-events-none absolute -top-12 -right-12 w-44 h-44 rounded-full bg-primary/25 blur-3xl"></div>
            <div class="pointer-events-none absolute -bottom-12 -left-12 w-44 h-44 rounded-full bg-secondary/20 blur-3xl"></div>
            <div class="p-6 sm:p-8 text-center relative z-10">
              <div class="flex justify-center mb-3">
                <div class="w-12 h-12 icon-tile icon-tile-primary animate-float">
                  <.icon name="hero-rocket-launch-solid" class="size-6" />
                </div>
              </div>
              <h2 class="text-xl font-bold text-gradient-brand">Ready to start your fitness journey?</h2>
              <p class="text-base-content/60 mt-2">
                Sign up to join a gym, book classes, and track your progress.
              </p>
              <div class="flex flex-wrap justify-center gap-3 mt-4 text-xs text-base-content/60">
                <span class="flex items-center gap-1"><.icon name="hero-check-circle-solid" class="size-3.5 text-success" /> Free signup</span>
                <span class="flex items-center gap-1"><.icon name="hero-check-circle-solid" class="size-3.5 text-success" /> No credit card</span>
                <span class="flex items-center gap-1"><.icon name="hero-check-circle-solid" class="size-3.5 text-success" /> Instant access</span>
              </div>
              <div class="mt-5">
                <a href="/register" class="btn btn-gradient gap-2 font-semibold">
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
