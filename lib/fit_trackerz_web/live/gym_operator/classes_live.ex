defmodule FitTrackerzWeb.GymOperator.ClassesLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        class_definitions = case FitTrackerz.Scheduling.list_class_definitions_by_gym(gym.id, actor: actor) do
          {:ok, defs} -> defs
          _ -> []
        end

        branches = case FitTrackerz.Gym.list_branches_by_gym(gym.id, actor: actor) do
          {:ok, branches} -> branches
          _ -> []
        end

        branch_ids = Enum.map(branches, & &1.id)

        scheduled_classes = case FitTrackerz.Scheduling.list_classes_by_branch(branch_ids, actor: actor, load: [:class_definition, :branch]) do
          {:ok, classes} -> classes
          _ -> []
        end

        def_form =
          to_form(
            %{
              "name" => "",
              "class_type" => "",
              "default_duration_minutes" => "60",
              "max_participants" => ""
            },
            as: "class_def"
          )

        schedule_form =
          to_form(
            %{
              "class_definition_id" => "",
              "scheduled_at" => "",
              "duration_minutes" => "60"
            },
            as: "schedule"
          )

        {:ok,
         assign(socket,
           page_title: "Classes",
           gym: gym,
           class_definitions: class_definitions,
           scheduled_classes: scheduled_classes,
           def_form: def_form,
           schedule_form: schedule_form,
           active_tab: "definitions",
           show_def_form: false,
           show_schedule_form: false
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Classes",
           gym: nil,
           class_definitions: [],
           scheduled_classes: [],
           def_form: nil,
           schedule_form: nil,
           active_tab: "definitions",
           show_def_form: false,
           show_schedule_form: false
         )}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("toggle_def_form", _params, socket) do
    {:noreply, assign(socket, show_def_form: !socket.assigns.show_def_form)}
  end

  def handle_event("toggle_schedule_form", _params, socket) do
    {:noreply, assign(socket, show_schedule_form: !socket.assigns.show_schedule_form)}
  end

  def handle_event("validate_def", %{"class_def" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_schedule", %{"schedule" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_definition", %{"class_def" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    max_p =
      case Integer.parse(params["max_participants"] || "") do
        {n, _} -> n
        :error -> nil
      end

    duration =
      case Integer.parse(params["default_duration_minutes"] || "") do
        {n, _} -> n
        :error -> 60
      end

    case FitTrackerz.Scheduling.create_class_definition(%{
      name: params["name"],
      class_type: params["class_type"],
      default_duration_minutes: duration,
      max_participants: max_p,
      gym_id: gym.id
    }, actor: actor) do
      {:ok, _def} ->
        class_definitions = case FitTrackerz.Scheduling.list_class_definitions_by_gym(gym.id, actor: actor) do
          {:ok, defs} -> defs
          _ -> []
        end

        def_form =
          to_form(
            %{
              "name" => "",
              "class_type" => "",
              "default_duration_minutes" => "60",
              "max_participants" => ""
            },
            as: "class_def"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Class type created successfully!")
         |> assign(class_definitions: class_definitions, def_form: def_form, show_def_form: false)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("save_schedule", %{"schedule" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    branch = case FitTrackerz.Gym.list_branches_by_gym(gym.id, actor: actor) do
      {:ok, [branch | _]} -> branch
      _ -> nil
    end

    branch_id = if branch, do: branch.id, else: nil

    sched_duration =
      case Integer.parse(params["duration_minutes"] || "") do
        {n, _} -> n
        :error -> 60
      end

    case FitTrackerz.Scheduling.create_scheduled_class(%{
      class_definition_id: params["class_definition_id"],
      branch_id: branch_id,
      scheduled_at: params["scheduled_at"],
      duration_minutes: sched_duration
    }, actor: actor) do
      {:ok, _class} ->
        branches = case FitTrackerz.Gym.list_branches_by_gym(gym.id, actor: actor) do
          {:ok, branches} -> branches
          _ -> []
        end

        branch_ids = Enum.map(branches, & &1.id)

        scheduled_classes = case FitTrackerz.Scheduling.list_classes_by_branch(branch_ids, actor: actor, load: [:class_definition, :branch]) do
          {:ok, classes} -> classes
          _ -> []
        end

        schedule_form =
          to_form(
            %{
              "class_definition_id" => "",
              "scheduled_at" => "",
              "duration_minutes" => "60"
            },
            as: "schedule"
          )

        {:noreply,
         socket
         |> put_flash(:info, "Class scheduled successfully!")
         |> assign(
           scheduled_classes: scheduled_classes,
           schedule_form: schedule_form,
           show_schedule_form: false
         )}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  defp schedule_status_class(:scheduled), do: "badge-info"
  defp schedule_status_class(:completed), do: "badge-success"
  defp schedule_status_class(:cancelled), do: "badge-error"
  defp schedule_status_class(_), do: "badge-neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Classes</h1>
              <p class="text-base-content/50 mt-1">Manage class types and scheduled sessions.</p>
            </div>
          </div>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing classes.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Tabs --%>
          <div class="tabs tabs-bordered" id="classes-tabs">
            <button
              phx-click="switch_tab"
              phx-value-tab="definitions"
              class={"tab #{if @active_tab == "definitions", do: "tab-active"}"}
              id="tab-definitions"
            >
              <.icon name="hero-rectangle-stack" class="size-4 mr-2" /> Class Types
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="scheduled"
              class={"tab #{if @active_tab == "scheduled", do: "tab-active"}"}
              id="tab-scheduled"
            >
              <.icon name="hero-calendar-days" class="size-4 mr-2" /> Scheduled Classes
            </button>
          </div>

          <%!-- Class Definitions Tab --%>
          <%= if @active_tab == "definitions" do %>
            <div class="space-y-6">
              <div class="flex justify-end">
                <button
                  phx-click="toggle_def_form"
                  class="btn btn-primary btn-sm gap-2"
                  id="toggle-def-form-btn"
                >
                  <.icon name="hero-plus-mini" class="size-4" /> Add Class Type
                </button>
              </div>

              <%= if @show_def_form do %>
                <div class="card bg-base-200/50 border border-base-300/50" id="add-def-card">
                  <div class="card-body p-6">
                    <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                      <.icon name="hero-plus-circle-solid" class="size-5 text-info" /> New Class Type
                    </h2>
                    <.form
                      for={@def_form}
                      id="add-def-form"
                      phx-change="validate_def"
                      phx-submit="save_definition"
                    >
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <.input
                          field={@def_form[:name]}
                          label="Class Name"
                          placeholder="e.g. Yoga Basics"
                          required
                        />
                        <.input
                          field={@def_form[:class_type]}
                          label="Class Type"
                          placeholder="e.g. yoga, cardio, strength"
                          required
                        />
                        <.input
                          field={@def_form[:default_duration_minutes]}
                          type="number"
                          label="Default Duration (minutes)"
                          required
                        />
                        <.input
                          field={@def_form[:max_participants]}
                          type="number"
                          label="Max Participants"
                          placeholder="Leave empty for unlimited"
                        />
                      </div>
                      <div class="flex gap-2 mt-4">
                        <button type="submit" class="btn btn-primary btn-sm gap-2" id="save-def-btn">
                          <.icon name="hero-check-mini" class="size-4" /> Save Class Type
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_def_form"
                          class="btn btn-ghost btn-sm"
                          id="cancel-def-btn"
                        >
                          Cancel
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              <% end %>

              <div class="card bg-base-200/50 border border-base-300/50" id="definitions-table-card">
                <div class="card-body p-6">
                  <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                    <.icon name="hero-rectangle-stack-solid" class="size-5 text-info" /> Class Types
                    <span class="badge badge-neutral badge-sm">{length(@class_definitions)}</span>
                  </h2>
                  <%= if @class_definitions == [] do %>
                    <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                      <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                      <p class="text-sm text-base-content/50">
                        No class types defined yet. Create one to get started.
                      </p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm" id="definitions-table">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Name</th>
                            <th>Type</th>
                            <th>Duration</th>
                            <th>Max Participants</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for cd <- @class_definitions do %>
                            <tr id={"class-def-#{cd.id}"}>
                              <td class="font-medium">{cd.name}</td>
                              <td><span class="badge badge-info badge-sm">{cd.class_type}</span></td>
                              <td>{cd.default_duration_minutes} min</td>
                              <td>{cd.max_participants || "Unlimited"}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Scheduled Classes Tab --%>
          <%= if @active_tab == "scheduled" do %>
            <div class="space-y-6">
              <div class="flex justify-end">
                <button
                  phx-click="toggle_schedule_form"
                  class="btn btn-primary btn-sm gap-2"
                  id="toggle-schedule-form-btn"
                >
                  <.icon name="hero-plus-mini" class="size-4" /> Schedule Class
                </button>
              </div>

              <%= if @show_schedule_form do %>
                <div class="card bg-base-200/50 border border-base-300/50" id="add-schedule-card">
                  <div class="card-body p-6">
                    <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                      <.icon name="hero-calendar-days-solid" class="size-5 text-info" />
                      Schedule New Class
                    </h2>
                    <.form
                      for={@schedule_form}
                      id="add-schedule-form"
                      phx-change="validate_schedule"
                      phx-submit="save_schedule"
                    >
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <.input
                          field={@schedule_form[:class_definition_id]}
                          type="select"
                          label="Class Type"
                          prompt="Select a class type"
                          options={Enum.map(@class_definitions, &{&1.name, &1.id})}
                          required
                        />
                        <.input
                          field={@schedule_form[:scheduled_at]}
                          type="datetime-local"
                          label="Scheduled At"
                          required
                        />
                        <.input
                          field={@schedule_form[:duration_minutes]}
                          type="number"
                          label="Duration (minutes)"
                          required
                        />
                      </div>
                      <div class="flex gap-2 mt-4">
                        <button
                          type="submit"
                          class="btn btn-primary btn-sm gap-2"
                          id="save-schedule-btn"
                        >
                          <.icon name="hero-check-mini" class="size-4" /> Schedule Class
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_schedule_form"
                          class="btn btn-ghost btn-sm"
                          id="cancel-schedule-btn"
                        >
                          Cancel
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              <% end %>

              <div class="card bg-base-200/50 border border-base-300/50" id="scheduled-table-card">
                <div class="card-body p-6">
                  <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                    <.icon name="hero-calendar-days-solid" class="size-5 text-info" />
                    Scheduled Classes
                    <span class="badge badge-neutral badge-sm">{length(@scheduled_classes)}</span>
                  </h2>
                  <%= if @scheduled_classes == [] do %>
                    <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                      <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                      <p class="text-sm text-base-content/50">No classes scheduled yet.</p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-sm" id="scheduled-table">
                        <thead>
                          <tr class="text-base-content/40">
                            <th>Class</th>
                            <th>Scheduled At</th>
                            <th>Duration</th>
                            <th>Status</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for sc <- @scheduled_classes do %>
                            <tr id={"scheduled-#{sc.id}"}>
                              <td class="font-medium">{sc.class_definition.name}</td>
                              <td>{Calendar.strftime(sc.scheduled_at, "%b %d, %Y %I:%M %p")}</td>
                              <td>{sc.duration_minutes} min</td>
                              <td>
                                <span class={"badge badge-sm #{schedule_status_class(sc.status)}"}>
                                  {Phoenix.Naming.humanize(sc.status)}
                                </span>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
