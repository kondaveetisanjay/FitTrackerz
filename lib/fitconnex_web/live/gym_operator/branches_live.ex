defmodule FitconnexWeb.GymOperator.BranchesLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    case find_gym(user.id) do
      {:ok, gym} ->
        gid = gym.id

        branches =
          Fitconnex.Gym.GymBranch
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.read!()

        form =
          to_form(
            %{
              "address" => "",
              "city" => "",
              "state" => "",
              "postal_code" => "",
              "latitude" => "",
              "longitude" => "",
              "is_primary" => "false"
            },
            as: "branch"
          )

        {:ok,
         socket
         |> assign(
           page_title: "Branches",
           gym: gym,
           branches: branches,
           form: form,
           show_form: false,
           editing_branch_id: nil,
           edit_form: nil,
           editing_branch_logo: nil,
           editing_branch_gallery: []
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

      :no_gym ->
        {:ok,
         socket
         |> assign(
           page_title: "Branches",
           gym: nil,
           branches: [],
           form: nil,
           show_form: false,
           editing_branch_id: nil,
           edit_form: nil,
           editing_branch_logo: nil,
           editing_branch_gallery: []
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

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("validate", %{"branch" => _params}, socket) do
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
      "longitude" => lng_str,
      "is_primary" => "false"
    }

    if socket.assigns.editing_branch_id do
      # Preserve the is_primary value from the current edit form
      old_primary = socket.assigns.edit_form.params["is_primary"] || "false"
      edit_form = to_form(Map.put(form_data, "is_primary", old_primary), as: "branch")
      {:noreply, assign(socket, edit_form: edit_form)}
    else
      form = to_form(form_data, as: "branch")
      {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("save_branch", %{"branch" => params}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    lat = parse_float(params["latitude"])
    lng = parse_float(params["longitude"])

    # Consume uploaded logo
    logo_url =
      case consume_uploaded_entries(socket, :logo, &save_upload/2) do
        [url] -> url
        [] -> nil
      end

    # Consume uploaded gallery images
    gallery_urls = consume_uploaded_entries(socket, :gallery, &save_upload/2)

    create_params = %{
      address: params["address"],
      city: params["city"],
      state: params["state"],
      postal_code: params["postal_code"],
      latitude: lat,
      longitude: lng,
      is_primary: params["is_primary"] == "true",
      gym_id: gym.id,
      logo_url: logo_url,
      gallery_urls: gallery_urls
    }

    case Fitconnex.Gym.GymBranch
         |> Ash.Changeset.for_create(:create, create_params)
         |> Ash.create() do
      {:ok, _branch} ->
        branches =
          Fitconnex.Gym.GymBranch
          |> Ash.Query.filter(gym_id == ^gid)
          |> Ash.read!()

        form =
          to_form(
            %{
              "address" => "",
              "city" => "",
              "state" => "",
              "postal_code" => "",
              "latitude" => "",
              "longitude" => "",
              "is_primary" => "false"
            },
            as: "branch"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Branch added successfully!")
         |> assign(branches: branches, form: form, show_form: false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add branch. Please check your input.")}
    end
  end

  def handle_event("delete_branch", %{"id" => id}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    branch =
      Fitconnex.Gym.GymBranch
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.filter(gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if branch do
      case Ash.destroy(branch) do
        :ok ->
          branches =
            Fitconnex.Gym.GymBranch
            |> Ash.Query.filter(gym_id == ^gid)
            |> Ash.read!()

          {:noreply,
           socket
           |> put_flash(:info, "Branch deleted.")
           |> assign(branches: branches)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete branch.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Branch not found.")}
    end
  end

  def handle_event("edit_branch", %{"id" => id}, socket) do
    gym = socket.assigns.gym
    gid = gym.id

    branch =
      Fitconnex.Gym.GymBranch
      |> Ash.Query.filter(id == ^id and gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if branch do
      edit_form =
        to_form(
          %{
            "address" => branch.address || "",
            "city" => branch.city || "",
            "state" => branch.state || "",
            "postal_code" => branch.postal_code || "",
            "latitude" => if(branch.latitude, do: to_string(branch.latitude), else: ""),
            "longitude" => if(branch.longitude, do: to_string(branch.longitude), else: ""),
            "is_primary" => to_string(branch.is_primary)
          },
          as: "branch"
        )

      {:noreply,
       assign(socket,
         editing_branch_id: id,
         edit_form: edit_form,
         show_form: false,
         editing_branch_logo: branch.logo_url,
         editing_branch_gallery: branch.gallery_urls || []
       )}
    else
      {:noreply, put_flash(socket, :error, "Branch not found.")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     assign(socket,
       editing_branch_id: nil,
       edit_form: nil,
       editing_branch_logo: nil,
       editing_branch_gallery: []
     )}
  end

  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
  end

  def handle_event("remove_existing_logo", _params, socket) do
    {:noreply, assign(socket, editing_branch_logo: nil)}
  end

  def handle_event("remove_gallery_image", %{"url" => url}, socket) do
    updated = Enum.reject(socket.assigns.editing_branch_gallery, &(&1 == url))
    {:noreply, assign(socket, editing_branch_gallery: updated)}
  end

  def handle_event("update_branch", %{"branch" => params}, socket) do
    gym = socket.assigns.gym
    gid = gym.id
    branch_id = socket.assigns.editing_branch_id

    branch =
      Fitconnex.Gym.GymBranch
      |> Ash.Query.filter(id == ^branch_id and gym_id == ^gid)
      |> Ash.read!()
      |> List.first()

    if branch do
      # Handle logo: new upload takes priority, otherwise keep/remove existing
      new_logo =
        case consume_uploaded_entries(socket, :logo, &save_upload/2) do
          [url] ->
            if branch.logo_url, do: delete_upload_file(branch.logo_url)
            url

          [] ->
            # Use the tracked value from assigns (nil if removed)
            socket.assigns.editing_branch_logo
        end

      # Handle gallery: merge kept existing + new uploads
      kept_gallery = socket.assigns.editing_branch_gallery
      new_gallery_urls = consume_uploaded_entries(socket, :gallery, &save_upload/2)

      # Delete removed gallery files from disk
      removed =
        (branch.gallery_urls || []) -- kept_gallery

      Enum.each(removed, &delete_upload_file/1)

      final_gallery = Enum.take(kept_gallery ++ new_gallery_urls, 6)

      update_params = %{
        address: params["address"],
        city: params["city"],
        state: params["state"],
        postal_code: params["postal_code"],
        latitude: parse_float(params["latitude"]),
        longitude: parse_float(params["longitude"]),
        is_primary: params["is_primary"] == "true",
        logo_url: new_logo,
        gallery_urls: final_gallery
      }

      case branch
           |> Ash.Changeset.for_update(:update, update_params)
           |> Ash.update() do
        {:ok, _updated} ->
          branches =
            Fitconnex.Gym.GymBranch
            |> Ash.Query.filter(gym_id == ^gid)
            |> Ash.read!()

          {:noreply,
           socket
           |> put_flash(:info, "Branch updated successfully!")
           |> assign(
             branches: branches,
             editing_branch_id: nil,
             edit_form: nil,
             editing_branch_logo: nil,
             editing_branch_gallery: []
           )}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update branch. Please check your input.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Branch not found.")}
    end
  end

  defp find_gym(user_id) do
    case Fitconnex.Gym.Gym
         |> Ash.Query.filter(owner_id == ^user_id)
         |> Ash.read!() do
      [gym | _] -> {:ok, gym}
      [] -> :no_gym
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Branches</h1>
              <p class="text-base-content/50 mt-1">Manage your gym locations.</p>
            </div>
          </div>
          <%= if @gym do %>
            <button
              phx-click="toggle_form"
              class="btn btn-primary btn-sm gap-2 font-semibold"
              id="toggle-branch-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> Add Branch
            </button>
          <% end %>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing branches.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Add Branch Modal --%>
          <%= if @show_form do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="add-branch-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-map-pin-solid" class="size-5 text-accent" /> Add New Branch
                </h2>
                <.form for={@form} id="add-branch-form" phx-change="validate" phx-submit="save_branch">
                  <div class="mb-4" id="add-branch-place-wrapper" phx-update="ignore">
                    <label class="label">
                      <span class="label-text font-medium">Search Place</span>
                    </label>
                    <input
                      type="text"
                      id="add-branch-place-search"
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
                      field={@form[:address]}
                      label="Address"
                      placeholder="123 Main St"
                      required
                    />
                    <.input field={@form[:city]} label="City" placeholder="Mumbai" required />
                    <.input field={@form[:state]} label="State" placeholder="Maharashtra" required />
                    <.input
                      field={@form[:postal_code]}
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
                          field={@form[:latitude]}
                          label="Latitude"
                          type="number"
                          placeholder="17.4400"
                        />
                      </div>
                      <div class="flex-1 w-full">
                        <.input
                          field={@form[:longitude]}
                          label="Longitude"
                          type="number"
                          placeholder="78.3000"
                        />
                      </div>
                      <div class="pt-7">
                        <button
                          type="button"
                          id="detect-branch-location-btn"
                          phx-hook="BranchGeolocation"
                          class="btn btn-outline btn-sm gap-2 whitespace-nowrap"
                        >
                          <.icon name="hero-map-pin-mini" class="size-4" /> Detect my location
                        </button>
                      </div>
                    </div>
                  </div>
                  <.input field={@form[:is_primary]} type="checkbox" label="Primary Branch" />

                  <%!-- Logo Upload --%>
                  <div class="mt-4">
                    <label class="label">
                      <span class="label-text font-medium">Branch Logo</span>
                    </label>
                    <.live_file_input upload={@uploads.logo} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                    <%= for entry <- @uploads.logo.entries do %>
                      <div class="flex items-center gap-3 mt-2">
                        <.live_img_preview entry={entry} class="w-16 h-16 rounded-lg object-cover" />
                        <span class="text-sm truncate flex-1">{entry.client_name}</span>
                        <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="logo" class="btn btn-ghost btn-xs text-error">
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
                      <span class="label-text font-medium">Gallery Images <span class="text-base-content/40">(up to 6)</span></span>
                    </label>
                    <.live_file_input upload={@uploads.gallery} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                    <div class="flex flex-wrap gap-3 mt-2">
                      <%= for entry <- @uploads.gallery.entries do %>
                        <div class="relative">
                          <.live_img_preview entry={entry} class="w-20 h-20 rounded-lg object-cover" />
                          <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="gallery" class="btn btn-circle btn-xs btn-error absolute -top-2 -right-2">
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
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="save-branch-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Save Branch
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_form"
                      class="btn btn-ghost btn-sm"
                      id="cancel-branch-btn"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Edit Branch Form --%>
          <%= if @editing_branch_id do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="edit-branch-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-pencil-square-solid" class="size-5 text-info" /> Edit Branch
                </h2>
                <.form
                  for={@edit_form}
                  id="edit-branch-form"
                  phx-change="validate"
                  phx-submit="update_branch"
                >
                  <div class="mb-4" id="edit-branch-place-wrapper" phx-update="ignore">
                    <label class="label">
                      <span class="label-text font-medium">Search Place</span>
                    </label>
                    <input
                      type="text"
                      id="edit-branch-place-search"
                      phx-hook="PlacesAutocomplete"
                      placeholder="Search for a place to update fields..."
                      class="input input-bordered w-full"
                      autocomplete="off"
                    />
                    <p class="text-xs text-base-content/40 mt-1">
                      Search to auto-fill fields, or edit them manually below.
                    </p>
                  </div>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <.input
                      field={@edit_form[:address]}
                      label="Address"
                      placeholder="123 Main St"
                      required
                    />
                    <.input
                      field={@edit_form[:city]}
                      label="City"
                      placeholder="Mumbai"
                      required
                    />
                    <.input
                      field={@edit_form[:state]}
                      label="State"
                      placeholder="Maharashtra"
                      required
                    />
                    <.input
                      field={@edit_form[:postal_code]}
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
                          field={@edit_form[:latitude]}
                          label="Latitude"
                          type="number"
                          placeholder="17.4400"
                        />
                      </div>
                      <div class="flex-1 w-full">
                        <.input
                          field={@edit_form[:longitude]}
                          label="Longitude"
                          type="number"
                          placeholder="78.3000"
                        />
                      </div>
                      <div class="pt-7">
                        <button
                          type="button"
                          id="detect-edit-branch-location-btn"
                          phx-hook="BranchGeolocation"
                          class="btn btn-outline btn-sm gap-2 whitespace-nowrap"
                        >
                          <.icon name="hero-map-pin-mini" class="size-4" /> Detect my location
                        </button>
                      </div>
                    </div>
                  </div>
                  <.input field={@edit_form[:is_primary]} type="checkbox" label="Primary Branch" />

                  <%!-- Logo Upload --%>
                  <div class="mt-4">
                    <label class="label">
                      <span class="label-text font-medium">Branch Logo</span>
                    </label>
                    <%!-- Existing logo --%>
                    <%= if @editing_branch_logo do %>
                      <div class="flex items-center gap-3 mb-2 p-2 rounded-lg bg-base-300/20">
                        <img src={@editing_branch_logo} class="w-16 h-16 rounded-lg object-cover" />
                        <span class="text-sm text-base-content/60">Current logo</span>
                        <button type="button" phx-click="remove_existing_logo" class="btn btn-ghost btn-xs text-error ml-auto">
                          <.icon name="hero-trash-mini" class="size-4" /> Remove
                        </button>
                      </div>
                    <% end %>
                    <.live_file_input upload={@uploads.logo} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                    <%= for entry <- @uploads.logo.entries do %>
                      <div class="flex items-center gap-3 mt-2">
                        <.live_img_preview entry={entry} class="w-16 h-16 rounded-lg object-cover" />
                        <span class="text-sm truncate flex-1">{entry.client_name}</span>
                        <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="logo" class="btn btn-ghost btn-xs text-error">
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
                      <span class="label-text font-medium">Gallery Images <span class="text-base-content/40">(up to 6)</span></span>
                    </label>
                    <%!-- Existing gallery images --%>
                    <%= if @editing_branch_gallery != [] do %>
                      <div class="flex flex-wrap gap-3 mb-2">
                        <%= for url <- @editing_branch_gallery do %>
                          <div class="relative">
                            <img src={url} class="w-20 h-20 rounded-lg object-cover" />
                            <button type="button" phx-click="remove_gallery_image" phx-value-url={url} class="btn btn-circle btn-xs btn-error absolute -top-2 -right-2">
                              <.icon name="hero-x-mark-mini" class="size-3" />
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                    <.live_file_input upload={@uploads.gallery} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                    <div class="flex flex-wrap gap-3 mt-2">
                      <%= for entry <- @uploads.gallery.entries do %>
                        <div class="relative">
                          <.live_img_preview entry={entry} class="w-20 h-20 rounded-lg object-cover" />
                          <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="gallery" class="btn btn-circle btn-xs btn-error absolute -top-2 -right-2">
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
                    <button type="submit" class="btn btn-primary btn-sm gap-2" id="update-branch-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Update Branch
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_edit"
                      class="btn btn-ghost btn-sm"
                      id="cancel-edit-btn"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Branches Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="branches-table-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-map-pin-solid" class="size-5 text-accent" /> All Branches
                <span class="badge badge-neutral badge-sm">{length(@branches)}</span>
              </h2>
              <%= if @branches == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">
                    No branches added yet. Add your first location above.
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="branches-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Logo</th>
                        <th>Address</th>
                        <th>City</th>
                        <th>State</th>
                        <th>Postal Code</th>
                        <th>Primary</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for branch <- @branches do %>
                        <tr id={"branch-#{branch.id}"}>
                          <td>
                            <%= if branch.logo_url do %>
                              <img src={branch.logo_url} class="w-10 h-10 rounded-lg object-cover" />
                            <% else %>
                              <div class="w-10 h-10 rounded-lg bg-base-300/30 flex items-center justify-center">
                                <.icon name="hero-photo" class="size-5 text-base-content/20" />
                              </div>
                            <% end %>
                          </td>
                          <td class="font-medium">{branch.address}</td>
                          <td>{branch.city}</td>
                          <td>{branch.state}</td>
                          <td>{branch.postal_code}</td>
                          <td>
                            <%= if branch.is_primary do %>
                              <span class="badge badge-success badge-sm">Primary</span>
                            <% else %>
                              <span class="badge badge-neutral badge-sm">No</span>
                            <% end %>
                          </td>
                          <td class="flex gap-1">
                            <button
                              phx-click="edit_branch"
                              phx-value-id={branch.id}
                              class="btn btn-ghost btn-xs text-info"
                              id={"edit-branch-#{branch.id}"}
                            >
                              <.icon name="hero-pencil-square" class="size-4" />
                            </button>
                            <button
                              phx-click="delete_branch"
                              phx-value-id={branch.id}
                              data-confirm="Are you sure you want to delete this branch?"
                              class="btn btn-ghost btn-xs text-error"
                              id={"delete-branch-#{branch.id}"}
                            >
                              <.icon name="hero-trash" class="size-4" />
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
