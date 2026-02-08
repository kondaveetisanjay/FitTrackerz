defmodule FitconnexWeb.GymOperator.SetupLive do
  use FitconnexWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    gyms =
      Fitconnex.Gym.Gym
      |> Ash.Query.filter(owner_id == ^user.id)
      |> Ash.Query.load([:branches])
      |> Ash.read!()

    case gyms do
      [gym | _] ->
        form = to_form(%{"name" => gym.name, "description" => gym.description || ""}, as: "gym")

        {:ok,
         assign(socket,
           page_title: "My Gym",
           gym: gym,
           form: form,
           editing: false
         )}

      [] ->
        form = to_form(%{"name" => "", "slug" => "", "description" => ""}, as: "gym")

        {:ok,
         assign(socket,
           page_title: "Setup Gym",
           gym: nil,
           form: form,
           editing: false
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"gym" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"gym" => params}, socket) do
    user = socket.assigns.current_user

    case Fitconnex.Gym.Gym
         |> Ash.Changeset.for_create(:create, %{
           name: params["name"],
           slug: params["slug"],
           description: params["description"],
           owner_id: user.id
         })
         |> Ash.create() do
      {:ok, gym} ->
        gym = Ash.load!(gym, [:branches])

        form =
          to_form(%{"name" => gym.name, "description" => gym.description || ""}, as: "gym")

        {:noreply,
         socket
         |> put_flash(:info, "Gym created successfully!")
         |> assign(gym: gym, form: form, editing: false)}

      {:error, changeset} ->
        errors = format_errors(changeset)

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create gym: #{errors}")}
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

    case gym
         |> Ash.Changeset.for_update(:update, %{
           name: params["name"],
           description: params["description"]
         })
         |> Ash.update() do
      {:ok, updated_gym} ->
        updated_gym = Ash.load!(updated_gym, [:branches])

        form =
          to_form(
            %{"name" => updated_gym.name, "description" => updated_gym.description || ""},
            as: "gym"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Gym updated successfully!")
         |> assign(gym: updated_gym, form: form, editing: false)}

      {:error, changeset} ->
        errors = format_errors(changeset)

        {:noreply,
         socket
         |> put_flash(:error, "Failed to update gym: #{errors}")}
    end
  end

  defp format_errors(%Ash.Error.Invalid{} = error) do
    error.errors
    |> Enum.map(fn e -> e.message end)
    |> Enum.join(", ")
  end

  defp format_errors(_), do: "Unknown error"

  defp status_badge_class(:verified), do: "badge-success"
  defp status_badge_class(:pending_verification), do: "badge-warning"
  defp status_badge_class(:suspended), do: "badge-error"
  defp status_badge_class(_), do: "badge-neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-black tracking-tight">
              {if @gym, do: "My Gym", else: "Setup Your Gym"}
            </h1>
            <p class="text-base-content/50 mt-1">
              {if @gym,
                do: "Manage your gym profile and settings.",
                else: "Create your gym to get started."}
            </p>
          </div>
        </div>

        <%= if @gym do %>
          <%!-- Gym Details Card --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="gym-details-card">
            <div class="card-body p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-building-office-solid" class="size-5 text-primary" /> Gym Profile
                </h2>
                <div class="flex items-center gap-3">
                  <span class={"badge #{status_badge_class(@gym.status)}"}>
                    {Phoenix.Naming.humanize(@gym.status)}
                  </span>
                  <%= unless @editing do %>
                    <button phx-click="edit" class="btn btn-ghost btn-sm gap-1" id="edit-gym-btn">
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
                    <div class="fieldset mb-2">
                      <label>
                        <span class="label mb-1">Slug</span>
                        <input
                          type="text"
                          value={@gym.slug}
                          class="w-full input input-disabled"
                          disabled
                        />
                      </label>
                      <p class="text-xs text-base-content/40 mt-1">
                        Slug cannot be changed after creation
                      </p>
                    </div>
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
                      class="btn btn-ghost btn-sm"
                      id="cancel-edit-btn"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              <% else %>
                <div class="space-y-3">
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <span class="text-sm font-semibold text-base-content/60 w-24">Name</span>
                    <span class="text-sm font-medium">{@gym.name}</span>
                  </div>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <span class="text-sm font-semibold text-base-content/60 w-24">Slug</span>
                    <span class="text-sm font-medium">{@gym.slug}</span>
                  </div>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <span class="text-sm font-semibold text-base-content/60 w-24">Description</span>
                    <span class="text-sm font-medium">
                      {@gym.description || "No description set"}
                    </span>
                  </div>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <span class="text-sm font-semibold text-base-content/60 w-24">Branches</span>
                    <span class="text-sm font-medium">{length(@gym.branches)} location(s)</span>
                  </div>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-base-300/20">
                    <span class="text-sm font-semibold text-base-content/60 w-24">Promoted</span>
                    <span class={"badge badge-sm #{if @gym.is_promoted, do: "badge-success", else: "badge-neutral"}"}>
                      {if @gym.is_promoted, do: "Yes", else: "No"}
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <%!-- Create Gym Form --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="create-gym-card">
            <div class="card-body p-6">
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
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
