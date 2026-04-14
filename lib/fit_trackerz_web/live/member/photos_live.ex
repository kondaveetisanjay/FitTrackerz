defmodule FitTrackerzWeb.Member.PhotosLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships =
      case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
        {:ok, memberships} -> memberships
        _ -> []
      end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "Progress Photos",
           no_gym: true,
           photos: [],
           form: nil
         )}

      memberships ->
        membership = List.first(memberships)
        member_ids = Enum.map(memberships, & &1.id)

        photos =
          case FitTrackerz.Health.list_progress_photos(member_ids, actor: actor) do
            {:ok, photos} -> photos
            _ -> []
          end

        form =
          to_form(
            %{
              "taken_on" => Date.to_iso8601(Date.utc_today()),
              "category" => "front",
              "notes" => ""
            },
            as: "photo"
          )

        {:ok,
         socket
         |> assign(
           page_title: "Progress Photos",
           no_gym: false,
           membership: membership,
           photos: photos,
           form: form
         )
         |> allow_upload(:photo,
           accept: ~w(.jpg .jpeg .png .webp),
           max_file_size: 5_000_000,
           max_entries: 1
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"photo" => params}, socket) do
    form = to_form(params, as: "photo")
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def handle_event("save_photo", %{"photo" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest_dir = Path.join(["priv/static/uploads/progress", membership.id])
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)
        {:ok, "/uploads/progress/#{membership.id}/#{filename}"}
      end)

    case uploaded_files do
      [photo_url] ->
        attrs = %{
          member_id: membership.id,
          taken_on: params["taken_on"],
          photo_url: photo_url,
          category: String.to_existing_atom(params["category"]),
          notes: params["notes"]
        }

        case FitTrackerz.Health.create_progress_photo(attrs, actor: actor) do
          {:ok, _} ->
            {:noreply, reload_photos(socket) |> put_flash(:info, "Photo uploaded!")}

          {:error, error} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error)
             )}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please select a photo to upload.")}
    end
  end

  @impl true
  def handle_event("toggle_share", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    photo = Enum.find(socket.assigns.photos, &(&1.id == id))

    if photo do
      case FitTrackerz.Health.update_progress_photo(
             photo,
             %{shared_with_trainer: !photo.shared_with_trainer},
             actor: actor
           ) do
        {:ok, _} ->
          {:noreply, reload_photos(socket)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update sharing.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_photo", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    photo = Enum.find(socket.assigns.photos, &(&1.id == id))

    if photo do
      # Delete file from disk
      file_path = Path.join("priv/static", photo.photo_url)
      File.rm(file_path)

      case FitTrackerz.Health.destroy_progress_photo(photo, actor: actor) do
        :ok ->
          {:noreply, reload_photos(socket) |> put_flash(:info, "Photo deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete photo.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Photo not found.")}
    end
  end

  defp reload_photos(socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    photos =
      case FitTrackerz.Health.list_progress_photos([membership.id], actor: actor) do
        {:ok, photos} -> photos
        _ -> []
      end

    assign(socket, photos: photos)
  end

  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp category_label(:front), do: "Front"
  defp category_label(:side), do: "Side"
  defp category_label(:back), do: "Back"
  defp category_label(:other), do: "Other"
  defp category_label(_), do: "Other"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Progress Photos" subtitle="Track your transformation visually." back_path="/member/progress" />

      <%= if @no_gym do %>
        <.empty_state icon="hero-building-office-2" title="No Gym Membership" subtitle="Join a gym to track progress photos." />
      <% else %>
        <div class="space-y-6">
          <%!-- Upload Section --%>
          <.card title="Upload Photo" id="upload-card">
            <.form for={@form} id="photo-form" phx-change="validate" phx-submit="save_photo">
              <div class="space-y-4">
                <div class="border-2 border-dashed border-base-300 rounded-xl p-6 text-center">
                  <.live_file_input upload={@uploads.photo} class="hidden" />
                  <label for={@uploads.photo.ref} class="cursor-pointer space-y-2 block">
                    <.icon name="hero-camera" class="size-10 text-base-content/30 mx-auto" />
                    <p class="text-sm text-base-content/50">Click or drag a photo here</p>
                    <p class="text-xs text-base-content/30">JPG, PNG, WebP — max 5MB</p>
                  </label>

                  <%= for entry <- @uploads.photo.entries do %>
                    <div class="mt-3 flex items-center gap-3">
                      <.live_img_preview entry={entry} class="size-16 rounded-lg object-cover" />
                      <span class="text-sm">{entry.client_name}</span>
                      <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="btn btn-xs btn-ghost text-error">
                        Remove
                      </button>
                    </div>
                  <% end %>
                </div>

                <div class="flex flex-wrap gap-4 items-end">
                  <div>
                    <.input field={@form[:taken_on]} type="date" label="Date" required />
                  </div>
                  <div>
                    <.input field={@form[:category]} type="select" label="Category" options={[
                      {"Front", "front"}, {"Side", "side"}, {"Back", "back"}, {"Other", "other"}
                    ]} />
                  </div>
                  <div class="flex-1">
                    <.input field={@form[:notes]} type="text" label="Notes" placeholder="Optional" />
                  </div>
                  <div class="mb-2">
                    <.button variant="primary" size="sm" icon="hero-arrow-up-tray" type="submit" id="upload-btn">
                      Upload
                    </.button>
                  </div>
                </div>
              </div>
            </.form>
          </.card>

          <%!-- Gallery --%>
          <.card title="Gallery" id="gallery-card">
            <:header_actions>
              <.badge variant="neutral">{length(@photos)} photos</.badge>
            </:header_actions>
            <%= if @photos == [] do %>
              <.empty_state icon="hero-photo" title="No Photos Yet" subtitle="Upload your first progress photo above!" />
            <% else %>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                <%= for photo <- @photos do %>
                  <div class="relative group rounded-xl overflow-hidden bg-base-200" id={"photo-#{photo.id}"}>
                    <img src={photo.photo_url} alt={"Progress photo - #{category_label(photo.category)}"} class="w-full aspect-square object-cover" />
                    <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
                      <div class="absolute bottom-0 left-0 right-0 p-3 space-y-1">
                        <div class="flex items-center justify-between">
                          <.badge variant="neutral" size="sm">{category_label(photo.category)}</.badge>
                          <span class="text-xs text-white/70">{format_date(photo.taken_on)}</span>
                        </div>
                        <div class="flex items-center justify-between">
                          <button
                            phx-click="toggle_share"
                            phx-value-id={photo.id}
                            class={["btn btn-xs", if(photo.shared_with_trainer, do: "btn-success", else: "btn-ghost text-white")]}
                          >
                            <%= if photo.shared_with_trainer do %>
                              <.icon name="hero-eye-solid" class="size-3" /> Shared
                            <% else %>
                              <.icon name="hero-eye-slash" class="size-3" /> Private
                            <% end %>
                          </button>
                          <button
                            phx-click="delete_photo"
                            phx-value-id={photo.id}
                            data-confirm="Delete this photo?"
                            class="btn btn-xs btn-ghost text-error"
                          >
                            <.icon name="hero-trash" class="size-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.card>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
