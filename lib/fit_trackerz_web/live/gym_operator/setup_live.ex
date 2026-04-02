defmodule FitTrackerzWeb.GymOperator.SetupLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        branch = load_branch(gym.id, actor)

        form =
          to_form(
            %{"name" => gym.name, "slug" => gym.slug, "description" => gym.description || ""},
            as: "gym"
          )

        {:ok,
         socket
         |> assign(
           page_title: "My Gym",
           gym: gym,
           form: form,
           editing: false,
           branch: branch,
           editing_location: false,
           location_form: build_location_form(branch),
           existing_logo: if(branch, do: branch.logo_url, else: nil),
           existing_gallery: if(branch, do: branch.gallery_urls || [], else: []),
           current_step: 1,
           selected_equipment: gym.equipment || [],
           selected_services: gym.services || []
         )
         |> allow_upload(:logo,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: 1,
           max_file_size: 5_000_000
         )
         |> allow_upload(:gallery,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: 6,
           max_file_size: 5_000_000
         )}

      _ ->
        form = to_form(%{"name" => "", "slug" => "", "description" => ""}, as: "gym")

        {:ok,
         socket
         |> assign(
           page_title: "Setup Gym",
           gym: nil,
           form: form,
           editing: false,
           branch: nil,
           editing_location: false,
           location_form: build_location_form(nil),
           existing_logo: nil,
           existing_gallery: [],
           current_step: 1,
           selected_equipment: [],
           selected_services: []
         )
         |> allow_upload(:logo,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: 1,
           max_file_size: 5_000_000
         )
         |> allow_upload(:gallery,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: 6,
           max_file_size: 5_000_000
         )}
    end
  end

  # ── Step Navigation Events ──

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :current_step, min(socket.assigns.current_step + 1, 3))}
  end

  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :current_step, max(socket.assigns.current_step - 1, 1))}
  end

  def handle_event("go_to_step", %{"step" => step}, socket) do
    step = String.to_integer(step)
    {:noreply, assign(socket, :current_step, step)}
  end

  def handle_event("toggle_equipment", %{"item" => item}, socket) do
    current = socket.assigns.selected_equipment

    updated =
      if item in current,
        do: List.delete(current, item),
        else: current ++ [item]

    {:noreply, assign(socket, :selected_equipment, updated)}
  end

  def handle_event("toggle_service", %{"item" => item}, socket) do
    current = socket.assigns.selected_services

    updated =
      if item in current,
        do: List.delete(current, item),
        else: current ++ [item]

    {:noreply, assign(socket, :selected_services, updated)}
  end

  def handle_event("save_equipment_services", _params, socket) do
    gym = socket.assigns.gym
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.update_gym(
           gym,
           %{equipment: socket.assigns.selected_equipment, services: socket.assigns.selected_services},
           actor: actor
         ) do
      {:ok, updated_gym} ->
        {:noreply,
         socket
         |> put_flash(:info, "Equipment and services saved!")
         |> assign(gym: updated_gym)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save equipment and services.")}
    end
  end

  # ── Gym Events ──

  def handle_event("validate", %{"gym" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"gym" => params}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.create_gym(%{
      name: params["name"],
      slug: params["slug"],
      description: params["description"],
      owner_id: actor.id
    }, actor: actor) do
      {:ok, gym} ->
        form =
          to_form(
            %{"name" => gym.name, "slug" => gym.slug, "description" => gym.description || ""},
            as: "gym"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Gym created successfully!")
         |> assign(gym: gym, form: form, editing: false)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create gym: #{format_errors(changeset)}")}
    end
  end

  def handle_event("edit", _params, socket) do
    {:noreply, assign(socket, editing: true)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  def handle_event("update", %{"gym" => params}, socket) do
    gym = socket.assigns.gym
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.update_gym(gym, %{
      name: params["name"],
      slug: params["slug"],
      description: params["description"]
    }, actor: actor) do
      {:ok, updated_gym} ->
        form =
          to_form(
            %{
              "name" => updated_gym.name,
              "slug" => updated_gym.slug,
              "description" => updated_gym.description || ""
            },
            as: "gym"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Gym updated successfully!")
         |> assign(gym: updated_gym, form: form, editing: false)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update gym: #{format_errors(changeset)}")}
    end
  end

  # ── Location Events ──

  def handle_event("edit_location", _params, socket) do
    branch = socket.assigns.branch

    {:noreply,
     assign(socket,
       editing_location: true,
       location_form: build_location_form(branch),
       existing_logo: if(branch, do: branch.logo_url, else: nil),
       existing_gallery: if(branch, do: branch.gallery_urls || [], else: [])
     )}
  end

  def handle_event("cancel_location_edit", _params, socket) do
    {:noreply, assign(socket, editing_location: false)}
  end

  def handle_event("validate_location", %{"location" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("place_selected", params, socket) do
    lat_str = if params["latitude"], do: to_string(params["latitude"]), else: ""
    lng_str = if params["longitude"], do: to_string(params["longitude"]), else: ""

    form_data = %{
      "address" => params["address"] || "",
      "city" => params["city"] || "",
      "state" => params["state"] || "",
      "postal_code" => params["postal_code"] || "",
      "latitude" => lat_str,
      "longitude" => lng_str
    }

    {:noreply, assign(socket, location_form: to_form(form_data, as: "location"))}
  end

  def handle_event("save_location", %{"location" => params}, socket) do
    gym = socket.assigns.gym
    actor = socket.assigns.current_user
    branch = socket.assigns.branch

    # Consume uploaded logo
    new_logo =
      case consume_uploaded_entries(socket, :logo, &save_upload/2) do
        [url] ->
          if branch && branch.logo_url, do: delete_upload_file(branch.logo_url)
          url

        [] ->
          socket.assigns.existing_logo
      end

    # Handle gallery: kept existing + new uploads
    kept_gallery = socket.assigns.existing_gallery
    new_gallery_urls = consume_uploaded_entries(socket, :gallery, &save_upload/2)

    if branch do
      removed = (branch.gallery_urls || []) -- kept_gallery
      Enum.each(removed, &delete_upload_file/1)
    end

    final_gallery = Enum.take(kept_gallery ++ new_gallery_urls, 6)

    location_params = %{
      address: params["address"],
      city: params["city"],
      state: params["state"],
      postal_code: params["postal_code"],
      latitude: parse_float(params["latitude"]),
      longitude: parse_float(params["longitude"]),
      logo_url: new_logo,
      gallery_urls: final_gallery
    }

    result =
      if branch do
        FitTrackerz.Gym.update_branch(branch, location_params, actor: actor)
      else
        FitTrackerz.Gym.create_branch(Map.put(location_params, :gym_id, gym.id), actor: actor)
      end

    case result do
      {:ok, updated_branch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location saved successfully!")
         |> assign(
           branch: updated_branch,
           editing_location: false,
           existing_logo: updated_branch.logo_url,
           existing_gallery: updated_branch.gallery_urls || []
         )}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to save location: #{format_errors(changeset)}")}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
  end

  def handle_event("remove_existing_logo", _params, socket) do
    {:noreply, assign(socket, existing_logo: nil)}
  end

  def handle_event("remove_gallery_image", %{"url" => url}, socket) do
    updated = Enum.reject(socket.assigns.existing_gallery, &(&1 == url))
    {:noreply, assign(socket, existing_gallery: updated)}
  end

  # ── Helpers ──

  defp load_branch(gym_id, actor) do
    case FitTrackerz.Gym.list_branches_by_gym(gym_id, actor: actor) do
      {:ok, [branch | _]} -> branch
      _ -> nil
    end
  end

  defp build_location_form(nil) do
    to_form(
      %{
        "address" => "",
        "city" => "",
        "state" => "",
        "postal_code" => "",
        "latitude" => "",
        "longitude" => ""
      },
      as: "location"
    )
  end

  defp build_location_form(branch) do
    to_form(
      %{
        "address" => branch.address || "",
        "city" => branch.city || "",
        "state" => branch.state || "",
        "postal_code" => branch.postal_code || "",
        "latitude" => if(branch.latitude, do: to_string(branch.latitude), else: ""),
        "longitude" => if(branch.longitude, do: to_string(branch.longitude), else: "")
      },
      as: "location"
    )
  end

  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp save_upload(%{path: path}, entry) do
    upload_dir = Path.join(["priv/static/uploads/branches"])
    File.mkdir_p!(upload_dir)
    filename = "#{Ecto.UUID.generate()}#{Path.extname(entry.client_name)}"
    dest = Path.join(upload_dir, filename)
    File.cp!(path, dest)
    {:ok, "/uploads/branches/#{filename}"}
  end

  defp delete_upload_file(nil), do: :ok

  defp delete_upload_file(url) do
    path = Path.join("priv/static", url)
    File.rm(path)
    :ok
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp upload_error_to_string(:too_many_files), do: "Too many files"
  defp upload_error_to_string(:not_accepted), do: "Invalid file type (use JPG, PNG, or WebP)"
  defp upload_error_to_string(err), do: inspect(err)

  defp format_errors(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn
      %{message: msg} when is_binary(msg) -> msg
      e -> inspect(e)
    end)
    |> Enum.join(", ")
  end

  defp format_errors(error), do: inspect(error)

  defp status_badge_class(:verified), do: "badge-success"
  defp status_badge_class(:pending_verification), do: "badge-warning"
  defp status_badge_class(:suspended), do: "badge-error"
  defp status_badge_class(_), do: "badge-neutral"

  defp equipment_options do
    ["Cardio Machines", "Free Weights", "CrossFit Zone", "Swimming Pool",
     "Sauna", "Locker Rooms", "Juice Bar", "Parking", "AC", "Steam Room"]
  end

  defp services_options do
    ["Personal Training", "Group Classes", "Yoga", "Zumba", "Boxing",
     "Martial Arts", "Pilates", "HIIT", "Spinning", "Dance"]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">
              {if @gym, do: "My Gym", else: "Setup Your Gym"}
            </h1>
            <p class="text-base-content/50 mt-1">
              {if @gym,
                do: "Manage your gym profile and location.",
                else: "Create your gym to get started."}
            </p>
          </div>
        </div>

        <%= if @gym do %>
          <%!-- Progress Steps --%>
          <div class="flex items-center justify-center gap-2 mb-2">
            <%= for {label, step_num} <- [{"Basics", 1}, {"Location", 2}, {"Photos & Details", 3}] do %>
              <div class="flex items-center gap-2">
                <button
                  phx-click="go_to_step"
                  phx-value-step={step_num}
                  class={[
                    "w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold cursor-pointer press-scale",
                    if(@current_step >= step_num, do: "bg-primary text-primary-content", else: "bg-base-300 text-base-content/50")
                  ]}
                >
                  {step_num}
                </button>
                <span class={[
                  "text-sm font-medium hidden sm:inline",
                  if(@current_step >= step_num, do: "text-primary", else: "text-base-content/50")
                ]}>
                  {label}
                </span>
                <%= if step_num < 3 do %>
                  <div class={[
                    "w-12 h-0.5",
                    if(@current_step > step_num, do: "bg-primary", else: "bg-base-300")
                  ]} />
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- STEP 1: Gym Details --%>
          <%= if @current_step == 1 do %>
          <div class="ft-card p-6" id="gym-details-card">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-building-office-solid" class="size-5 text-primary" /> Step 1: Gym Profile
              </h2>
              <div class="flex items-center gap-3">
                <span class={"badge #{status_badge_class(@gym.status)}"}>
                  {Phoenix.Naming.humanize(@gym.status)}
                </span>
                <%= unless @editing do %>
                  <button phx-click="edit" class="btn btn-ghost btn-sm gap-1 press-scale" id="edit-gym-btn">
                    <.icon name="hero-pencil-square" class="size-4" /> Edit
                  </button>
                <% end %>
              </div>
            </div>

            <%= if @editing do %>
              <.form for={@form} id="update-gym-form" phx-change="validate" phx-submit="update">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@form[:name]}
                    label="Gym Name"
                    placeholder="Enter gym name"
                    required
                  />
                  <.input
                    field={@form[:slug]}
                    label="Slug (URL-friendly)"
                    placeholder="e.g. iron-paradise"
                    required
                  />
                </div>
                <.input
                  field={@form[:description]}
                  type="textarea"
                  label="Description"
                  placeholder="Describe your gym..."
                />
                <div class="flex gap-2 mt-4">
                  <button type="submit" class="btn btn-primary btn-sm gap-2" id="save-update-btn">
                    <.icon name="hero-check-mini" class="size-4" /> Save Changes
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    class="btn btn-ghost btn-sm press-scale"
                    id="cancel-edit-btn"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            <% else %>
              <div class="space-y-3">
                <div class="flex items-center gap-3 p-3 bg-base-200/30 rounded-xl">
                  <span class="text-sm font-semibold text-base-content/60 w-24">Name</span>
                  <span class="text-sm font-medium">{@gym.name}</span>
                </div>
                <div class="flex items-center gap-3 p-3 bg-base-200/30 rounded-xl">
                  <span class="text-sm font-semibold text-base-content/60 w-24">Slug</span>
                  <span class="text-sm font-medium">{@gym.slug}</span>
                </div>
                <div class="flex items-center gap-3 p-3 bg-base-200/30 rounded-xl">
                  <span class="text-sm font-semibold text-base-content/60 w-24">Description</span>
                  <span class="text-sm font-medium">
                    {@gym.description || "No description set"}
                  </span>
                </div>
                <div class="flex items-center gap-3 p-3 bg-base-200/30 rounded-xl">
                  <span class="text-sm font-semibold text-base-content/60 w-24">Promoted</span>
                  <span class={"badge badge-sm #{if @gym.is_promoted, do: "badge-success", else: "badge-neutral"}"}>
                    {if @gym.is_promoted, do: "Yes", else: "No"}
                  </span>
                </div>
              </div>
            <% end %>

            <%!-- Step Navigation --%>
            <div class="flex justify-end mt-6 pt-4 border-t border-base-200/50">
              <button phx-click="next_step" class="btn btn-primary btn-sm gap-2 press-scale">
                Next: Location <.icon name="hero-arrow-right-mini" class="size-4" />
              </button>
            </div>
          </div>
          <% end %>

          <%!-- STEP 2: Location Card --%>
          <%= if @current_step == 2 do %>
          <div class="ft-card p-6" id="location-card">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-map-pin-solid" class="size-5 text-accent" /> Step 2: Location
              </h2>
              <%= unless @editing_location do %>
                <button
                  phx-click="edit_location"
                  class="btn btn-ghost btn-sm gap-1 press-scale"
                  id="edit-location-btn"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  {if @branch, do: "Edit", else: "Add Location"}
                </button>
              <% end %>
            </div>

            <%= if @editing_location do %>
              <%!-- Location Edit Form --%>
              <.form
                for={@location_form}
                id="location-form"
                phx-change="validate_location"
                phx-submit="save_location"
              >
                <div class="mb-4" id="location-place-wrapper" phx-update="ignore">
                  <label class="label">
                    <span class="label-text font-medium">Search Place</span>
                  </label>
                  <input
                    type="text"
                    id="location-place-search"
                    phx-hook="PlacesAutocomplete"
                    placeholder="Search for a place, e.g. 'Jaguar Gym Hyderabad'..."
                    class="input input-bordered w-full"
                    autocomplete="off"
                  />
                  <p class="text-xs text-base-content/40 mt-1">
                    Start typing to search. Selecting a place will auto-fill the fields below.
                  </p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@location_form[:address]}
                    label="Address"
                    placeholder="123 Main St"
                    required
                  />
                  <.input
                    field={@location_form[:city]}
                    label="City"
                    placeholder="Mumbai"
                    required
                  />
                  <.input
                    field={@location_form[:state]}
                    label="State"
                    placeholder="Maharashtra"
                    required
                  />
                  <.input
                    field={@location_form[:postal_code]}
                    label="Postal Code"
                    placeholder="400001"
                    required
                  />
                </div>

                <div class="mt-4">
                  <label class="label">
                    <span class="label-text font-medium">Location Coordinates</span>
                  </label>
                  <div class="flex flex-col sm:flex-row gap-3 items-start">
                    <div class="flex-1 w-full">
                      <.input
                        field={@location_form[:latitude]}
                        label="Latitude"
                        type="number"
                        placeholder="17.4400"
                      />
                    </div>
                    <div class="flex-1 w-full">
                      <.input
                        field={@location_form[:longitude]}
                        label="Longitude"
                        type="number"
                        placeholder="78.3000"
                      />
                    </div>
                    <div class="pt-7">
                      <button
                        type="button"
                        id="detect-location-btn"
                        phx-hook="BranchGeolocation"
                        class="btn btn-outline btn-sm gap-2 whitespace-nowrap"
                      >
                        <.icon name="hero-map-pin-mini" class="size-4" /> Detect my location
                      </button>
                    </div>
                  </div>
                </div>

                <%!-- Logo Upload --%>
                <div class="mt-4">
                  <label class="label">
                    <span class="label-text font-medium">Gym Logo</span>
                  </label>
                  <%= if @existing_logo do %>
                    <div class="flex items-center gap-3 mb-2 p-2 bg-base-200/30 rounded-xl">
                      <img
                        src={@existing_logo}
                        class="w-16 h-16 rounded-lg object-cover"
                      />
                      <span class="text-sm text-base-content/60">Current logo</span>
                      <button
                        type="button"
                        phx-click="remove_existing_logo"
                        class="btn btn-ghost btn-xs text-error ml-auto press-scale"
                      >
                        <.icon name="hero-trash-mini" class="size-4" /> Remove
                      </button>
                    </div>
                  <% end %>
                  <.live_file_input
                    upload={@uploads.logo}
                    class="file-input file-input-bordered file-input-sm w-full max-w-xs"
                  />
                  <%= for entry <- @uploads.logo.entries do %>
                    <div class="flex items-center gap-3 mt-2">
                      <.live_img_preview
                        entry={entry}
                        class="w-16 h-16 rounded-lg object-cover"
                      />
                      <span class="text-sm truncate flex-1">{entry.client_name}</span>
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        phx-value-upload="logo"
                        class="btn btn-ghost btn-xs text-error press-scale"
                      >
                        <.icon name="hero-x-mark-mini" class="size-4" />
                      </button>
                    </div>
                    <%= for err <- upload_errors(@uploads.logo, entry) do %>
                      <p class="text-xs text-error mt-1">{upload_error_to_string(err)}</p>
                    <% end %>
                  <% end %>
                </div>

                <%!-- Gallery Upload --%>
                <div class="mt-4">
                  <label class="label">
                    <span class="label-text font-medium">
                      Gallery Images <span class="text-base-content/40">(up to 6)</span>
                    </span>
                  </label>
                  <%= if @existing_gallery != [] do %>
                    <div class="flex flex-wrap gap-3 mb-2">
                      <%= for url <- @existing_gallery do %>
                        <div class="relative">
                          <img
                            src={url}
                            class="w-20 h-20 rounded-lg object-cover"
                          />
                          <button
                            type="button"
                            phx-click="remove_gallery_image"
                            phx-value-url={url}
                            class="btn btn-circle btn-xs btn-error absolute -top-2 -right-2 press-scale"
                          >
                            <.icon name="hero-x-mark-mini" class="size-3" />
                          </button>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                  <.live_file_input
                    upload={@uploads.gallery}
                    class="file-input file-input-bordered file-input-sm w-full max-w-xs"
                  />
                  <div class="flex flex-wrap gap-3 mt-2">
                    <%= for entry <- @uploads.gallery.entries do %>
                      <div class="relative">
                        <.live_img_preview
                          entry={entry}
                          class="w-20 h-20 rounded-lg object-cover"
                        />
                        <button
                          type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          phx-value-upload="gallery"
                          class="btn btn-circle btn-xs btn-error absolute -top-2 -right-2 press-scale"
                        >
                          <.icon name="hero-x-mark-mini" class="size-3" />
                        </button>
                      </div>
                    <% end %>
                  </div>
                  <%= for err <- upload_errors(@uploads.gallery) do %>
                    <p class="text-xs text-error mt-1">{upload_error_to_string(err)}</p>
                  <% end %>
                </div>

                <div class="flex gap-2 mt-4">
                  <button
                    type="submit"
                    class="btn btn-primary btn-sm gap-2"
                    id="save-location-btn"
                  >
                    <.icon name="hero-check-mini" class="size-4" /> Save Location
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_location_edit"
                    class="btn btn-ghost btn-sm press-scale"
                    id="cancel-location-btn"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            <% else %>
              <%!-- Location Display --%>
              <%= if @branch do %>
                <div class="flex items-start gap-4 p-4 bg-base-200/30 rounded-xl">
                  <%= if @branch.logo_url do %>
                    <img
                      src={@branch.logo_url}
                      class="w-16 h-16 rounded-lg object-cover shrink-0"
                    />
                  <% else %>
                    <div class="w-16 h-16 rounded-lg bg-base-200/20 flex items-center justify-center shrink-0">
                      <.icon name="hero-photo" class="size-6 text-base-content/20" />
                    </div>
                  <% end %>

                  <div class="flex-1 min-w-0">
                    <p class="font-semibold">{@branch.city}, {@branch.state}</p>
                    <p class="text-sm text-base-content/60 mt-0.5">
                      {@branch.address} — {@branch.postal_code}
                    </p>
                    <%= if @branch.latitude && @branch.longitude do %>
                      <p class="text-xs text-base-content/40 mt-1">
                        Coordinates: {@branch.latitude}, {@branch.longitude}
                      </p>
                    <% end %>
                    <%= if @branch.gallery_urls && @branch.gallery_urls != [] do %>
                      <div class="flex gap-1.5 mt-3">
                        <%= for url <- @branch.gallery_urls do %>
                          <img
                            src={url}
                            alt="Gallery"
                            class="w-12 h-12 rounded object-cover"
                          />
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <%= if @branch.latitude && @branch.longitude do %>
                    <a
                      href={"https://www.google.com/maps?q=#{@branch.latitude},#{@branch.longitude}"}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="btn btn-outline btn-xs gap-1 shrink-0 self-center"
                    >
                      <.icon name="hero-map-pin-mini" class="size-3" /> Map
                    </a>
                  <% end %>
                </div>
              <% else %>
                <div class="flex items-center gap-3 p-4 bg-base-200/30 rounded-xl">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">
                    No location added yet. Add your gym's address and details.
                  </p>
                </div>
              <% end %>
            <% end %>

            <%!-- Step Navigation --%>
            <div class="flex justify-between mt-6 pt-4 border-t border-base-200/50">
              <button phx-click="prev_step" class="btn btn-ghost btn-sm gap-2 press-scale">
                <.icon name="hero-arrow-left-mini" class="size-4" /> Back: Basics
              </button>
              <button phx-click="next_step" class="btn btn-primary btn-sm gap-2 press-scale">
                Next: Photos & Details <.icon name="hero-arrow-right-mini" class="size-4" />
              </button>
            </div>
          </div>
          <% end %>

          <%!-- STEP 3: Photos & Equipment/Services --%>
          <%= if @current_step == 3 do %>
          <div class="ft-card p-6" id="photos-details-card">
            <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
              <.icon name="hero-photo-solid" class="size-5 text-info" /> Step 3: Photos & Details
            </h2>

            <%!-- Gallery images display --%>
            <%= if @existing_gallery != [] do %>
              <div class="mb-4">
                <label class="label"><span class="label-text font-semibold">Current Gallery</span></label>
                <div class="flex flex-wrap gap-3">
                  <%= for url <- @existing_gallery do %>
                    <img src={url} class="w-20 h-20 rounded-lg object-cover" alt="Gallery" />
                  <% end %>
                </div>
              </div>
            <% end %>

            <p class="text-sm text-base-content/60 mb-6">
              To update photos, go to the Location step and click Edit.
            </p>

            <%!-- Equipment & Amenities --%>
            <div class="mb-6">
              <label class="label"><span class="label-text font-semibold text-base">Equipment & Amenities</span></label>
              <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3 mt-2">
                <%= for item <- equipment_options() do %>
                  <label
                    class={[
                      "label cursor-pointer justify-start gap-2 p-2 rounded-lg border",
                      if(item in @selected_equipment, do: "border-primary bg-primary/5", else: "border-base-200/50 bg-base-200/30 rounded-xl")
                    ]}
                    phx-click="toggle_equipment"
                    phx-value-item={item}
                  >
                    <input
                      type="checkbox"
                      checked={item in @selected_equipment}
                      class="checkbox checkbox-primary checkbox-sm"
                      readonly
                    />
                    <span class="label-text text-sm">{item}</span>
                  </label>
                <% end %>
              </div>
            </div>

            <%!-- Services Offered --%>
            <div class="mb-6">
              <label class="label"><span class="label-text font-semibold text-base">Services Offered</span></label>
              <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3 mt-2">
                <%= for item <- services_options() do %>
                  <label
                    class={[
                      "label cursor-pointer justify-start gap-2 p-2 rounded-lg border",
                      if(item in @selected_services, do: "border-primary bg-primary/5", else: "border-base-200/50 bg-base-200/30 rounded-xl")
                    ]}
                    phx-click="toggle_service"
                    phx-value-item={item}
                  >
                    <input
                      type="checkbox"
                      checked={item in @selected_services}
                      class="checkbox checkbox-primary checkbox-sm"
                      readonly
                    />
                    <span class="label-text text-sm">{item}</span>
                  </label>
                <% end %>
              </div>
            </div>

            <%!-- Step Navigation --%>
            <div class="flex justify-between mt-6 pt-4 border-t border-base-200/50">
              <button phx-click="prev_step" class="btn btn-ghost btn-sm gap-2 press-scale">
                <.icon name="hero-arrow-left-mini" class="size-4" /> Back: Location
              </button>
              <button phx-click="save_equipment_services" class="btn btn-primary btn-sm gap-2 press-scale">
                <.icon name="hero-check-mini" class="size-4" /> Save & Complete Setup
              </button>
            </div>
          </div>
          <% end %>
        <% else %>
          <%!-- Create Gym Form --%>
          <div class="ft-card p-6" id="create-gym-card">
            <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
              <.icon name="hero-plus-circle-solid" class="size-5 text-primary" /> Create Your Gym
            </h2>
            <.form for={@form} id="create-gym-form" phx-change="validate" phx-submit="save">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@form[:name]}
                  label="Gym Name"
                  placeholder="e.g. Iron Paradise Fitness"
                  required
                />
                <.input
                  field={@form[:slug]}
                  label="Slug (URL-friendly)"
                  placeholder="e.g. iron-paradise"
                  required
                />
              </div>
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                placeholder="Tell members about your gym..."
              />
              <div class="mt-4">
                <button type="submit" class="btn btn-primary gap-2" id="create-gym-btn">
                  <.icon name="hero-plus-mini" class="size-4" /> Create Gym
                </button>
              </div>
            </.form>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
