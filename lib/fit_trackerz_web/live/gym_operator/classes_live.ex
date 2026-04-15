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

  defp schedule_status_variant(:scheduled), do: "info"
  defp schedule_status_variant(:completed), do: "success"
  defp schedule_status_variant(:cancelled), do: "error"
  defp schedule_status_variant(_), do: "neutral"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <.page_header title="Classes" subtitle="Manage class types and scheduled sessions." back_path="/gym" />

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before managing classes.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <.tab_group active={@active_tab} on_tab_change="switch_tab">
            <:tab id="definitions" label="Class Types" icon="hero-rectangle-stack">
              <div class="space-y-6">
                <div class="flex justify-end">
                  <.button variant="primary" size="sm" icon="hero-plus-mini" phx-click="toggle_def_form" id="toggle-def-form-btn">Add Class Type</.button>
                </div>

                <%= if @show_def_form do %>
                  <.card title="New Class Type" id="add-def-card">
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
                        />
                        <.input
                          field={@def_form[:class_type]}
                          label="Class Type"
                          placeholder="e.g. yoga, cardio, strength"
                        />
                        <.input
                          field={@def_form[:default_duration_minutes]}
                          type="number"
                          label="Default Duration (minutes)"
                        />
                        <.input
                          field={@def_form[:max_participants]}
                          type="number"
                          label="Max Participants"
                          placeholder="Leave empty for unlimited"
                        />
                      </div>
                      <div class="flex gap-2 mt-4">
                        <.button variant="primary" size="sm" icon="hero-check-mini" type="submit" id="save-def-btn">Save Class Type</.button>
                        <.button variant="ghost" size="sm" type="button" phx-click="toggle_def_form" id="cancel-def-btn">Cancel</.button>
                      </div>
                    </.form>
                  </.card>
                <% end %>

                <.card title="Class Types" subtitle={"#{length(@class_definitions)} types"}>
                  <%= if @class_definitions == [] do %>
                    <.empty_state icon="hero-rectangle-stack" title="No Class Types" subtitle="No class types defined yet. Create one to get started." />
                  <% else %>
                    <.data_table id="definitions-table" rows={@class_definitions} row_id={fn cd -> "class-def-#{cd.id}" end}>
                      <:col :let={cd} label="Name">
                        <span class="font-medium">{cd.name}</span>
                      </:col>
                      <:col :let={cd} label="Type">
                        <.badge variant="info" size="sm">{cd.class_type}</.badge>
                      </:col>
                      <:col :let={cd} label="Duration">
                        {cd.default_duration_minutes} min
                      </:col>
                      <:col :let={cd} label="Max Participants">
                        {cd.max_participants || "Unlimited"}
                      </:col>
                    </.data_table>
                  <% end %>
                </.card>
              </div>
            </:tab>

            <:tab id="scheduled" label="Scheduled Classes" icon="hero-calendar-days">
              <div class="space-y-6">
                <div class="flex justify-end">
                  <.button variant="primary" size="sm" icon="hero-plus-mini" phx-click="toggle_schedule_form" id="toggle-schedule-form-btn">Schedule Class</.button>
                </div>

                <%= if @show_schedule_form do %>
                  <.card title="Schedule New Class" id="add-schedule-card">
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
                        />
                        <.input
                          field={@schedule_form[:scheduled_at]}
                          type="datetime-local"
                          label="Scheduled At"
                        />
                        <.input
                          field={@schedule_form[:duration_minutes]}
                          type="number"
                          label="Duration (minutes)"
                        />
                      </div>
                      <div class="flex gap-2 mt-4">
                        <.button variant="primary" size="sm" icon="hero-check-mini" type="submit" id="save-schedule-btn">Schedule Class</.button>
                        <.button variant="ghost" size="sm" type="button" phx-click="toggle_schedule_form" id="cancel-schedule-btn">Cancel</.button>
                      </div>
                    </.form>
                  </.card>
                <% end %>

                <.card title="Scheduled Classes" subtitle={"#{length(@scheduled_classes)} classes"}>
                  <%= if @scheduled_classes == [] do %>
                    <.empty_state icon="hero-calendar-days" title="No Scheduled Classes" subtitle="No classes scheduled yet." />
                  <% else %>
                    <.data_table id="scheduled-table" rows={@scheduled_classes} row_id={fn sc -> "scheduled-#{sc.id}" end}>
                      <:col :let={sc} label="Class">
                        <span class="font-medium">{sc.class_definition.name}</span>
                      </:col>
                      <:col :let={sc} label="Scheduled At">
                        {Calendar.strftime(sc.scheduled_at, "%b %d, %Y %I:%M %p")}
                      </:col>
                      <:col :let={sc} label="Duration">
                        {sc.duration_minutes} min
                      </:col>
                      <:col :let={sc} label="Status">
                        <.badge variant={schedule_status_variant(sc.status)}>{Phoenix.Naming.humanize(sc.status)}</.badge>
                      </:col>
                    </.data_table>
                  <% end %>
                </.card>
              </div>
            </:tab>
          </.tab_group>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
