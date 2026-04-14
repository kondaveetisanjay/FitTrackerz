defmodule FitTrackerzWeb.Trainer.AttendanceLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case FitTrackerz.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
      {:ok, trainers} -> trainers
      _ -> []
    end

    if gym_trainers == [] do
      {:ok,
       socket
       |> assign(page_title: "Attendance")
       |> assign(no_gym: true, records: [], clients: [], gyms: [], form: nil, show_form: false)}
    else
      gyms = Enum.map(gym_trainers, & &1.gym)
      trainer_ids = Enum.map(gym_trainers, & &1.id)

      clients = case FitTrackerz.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user, :gym]) do
        {:ok, members} -> members
        _ -> []
      end

      member_ids = Enum.map(clients, & &1.id)

      records = case FitTrackerz.Training.list_attendance_by_member(member_ids, actor: actor, load: [:gym, member: [:user]]) do
        {:ok, records} -> Enum.filter(records, &(&1.marked_by_id == actor.id))
        _ -> []
      end

      now = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M")

      form =
        to_form(
          %{"member_id" => "", "attended_at" => now, "notes" => ""},
          as: "attendance"
        )

      {:ok,
       socket
       |> assign(page_title: "Attendance")
       |> assign(
         no_gym: false,
         records: records,
         clients: clients,
         gyms: gyms,
         form: form,
         show_form: false
       )}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("validate", %{"attendance" => params}, socket) do
    form = to_form(params, as: "attendance")
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save_attendance", %{"attendance" => params}, socket) do
    client =
      Enum.find(socket.assigns.clients, fn c -> c.id == params["member_id"] end)

    if client == nil do
      {:noreply, put_flash(socket, :error, "Please select a valid client.")}
    else
      attended_at =
        case DateTime.from_iso8601(params["attended_at"] <> ":00Z") do
          {:ok, dt, _offset} -> dt
          _ -> DateTime.utc_now()
        end

      actor = socket.assigns.current_user
      client_ids = Enum.map(socket.assigns.clients, & &1.id)

      case FitTrackerz.Training.create_attendance(%{
        attended_at: attended_at,
        notes: params["notes"],
        member_id: client.id,
        gym_id: client.gym_id,
        marked_by_id: actor.id
      }, actor: actor) do
        {:ok, _record} ->
          records = case FitTrackerz.Training.list_attendance_by_member(client_ids, actor: actor, load: [:gym, member: [:user]]) do
            {:ok, records} -> Enum.filter(records, &(&1.marked_by_id == actor.id))
            _ -> []
          end

          now = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M")

          form =
            to_form(%{"member_id" => "", "attended_at" => now, "notes" => ""}, as: "attendance")

          {:noreply,
           socket
           |> assign(records: records, form: form, show_form: false)
           |> put_flash(:info, "Attendance marked successfully.")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    end
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Attendance" subtitle="Track and manage client attendance records." back_path="/trainer">
        <:actions>
          <%= unless @no_gym do %>
            <.button variant="primary" size="sm" icon="hero-plus" phx-click="toggle_form" id="toggle-attendance-form-btn">
              Mark Attendance
            </.button>
          <% end %>
        </:actions>
      </.page_header>

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-exclamation-triangle"
          title="No Gym Association"
          subtitle="You haven't been added to any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Stats --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
          <.stat_card label="Total Records" value={length(@records)} icon="hero-clipboard-document-check-solid" color="primary" />
          <.stat_card label="Clients Tracked" value={length(@clients)} icon="hero-user-group-solid" color="info" />
        </div>

        <%!-- Mark Attendance Form --%>
        <%= if @show_form do %>
          <div class="mb-8">
            <.card title="Mark Attendance">
              <.form
                for={@form}
                id="attendance-form"
                phx-change="validate"
                phx-submit="save_attendance"
                class="space-y-4"
              >
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label class="label"><span class="label-text font-medium">Client</span></label>
                    <select
                      name="attendance[member_id]"
                      class="select select-bordered w-full"
                      id="attendance-member-select"
                      required
                    >
                      <option value="">Select a client...</option>
                      <option :for={client <- @clients} value={client.id}>
                        {if client.user, do: client.user.name, else: "Unknown"} ({if client.gym,
                          do: client.gym.name,
                          else: "N/A"})
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="label">
                      <span class="label-text font-medium">Attended At</span>
                    </label>
                    <input
                      type="datetime-local"
                      name="attendance[attended_at]"
                      value={@form[:attended_at].value}
                      class="input input-bordered w-full"
                      id="attendance-datetime-input"
                      required
                    />
                  </div>
                  <.input field={@form[:notes]} label="Notes" placeholder="Optional notes..." />
                </div>
                <div class="flex justify-end gap-2 pt-2">
                  <.button type="button" variant="ghost" size="sm" phx-click="toggle_form" id="cancel-attendance-btn">
                    Cancel
                  </.button>
                  <.button type="submit" variant="primary" size="sm" icon="hero-check" id="submit-attendance-btn">
                    Mark Present
                  </.button>
                </div>
              </.form>
            </.card>
          </div>
        <% end %>

        <%!-- Attendance Records --%>
        <.card title="Attendance Records">
          <%= if @records == [] do %>
            <.empty_state
              icon="hero-clipboard-document-list"
              title="No attendance records yet"
              subtitle="Use the Mark Attendance button to start tracking client attendance."
            />
          <% else %>
            <.data_table id="attendance-table" rows={@records} row_id={fn r -> "att-#{r.id}" end}>
              <:col :let={record} label="Member">
                <div class="flex items-center gap-2">
                  <%= if record.member && record.member.user do %>
                    <.avatar name={record.member.user.name} size="sm" />
                    <span class="font-medium">{record.member.user.name}</span>
                  <% else %>
                    <span class="text-base-content/40">Unknown</span>
                  <% end %>
                </div>
              </:col>
              <:col :let={record} label="Gym">
                {if record.gym, do: record.gym.name, else: "N/A"}
              </:col>
              <:col :let={record} label="Attended At">
                {format_datetime(record.attended_at)}
              </:col>
              <:col :let={record} label="Notes">
                <span class="max-w-xs truncate block">{record.notes || "-"}</span>
              </:col>
              <:col :let={record} label="Recorded">
                <span class="text-xs text-base-content/40">{format_datetime(record.inserted_at)}</span>
              </:col>
              <:mobile_card :let={record}>
                <div>
                  <p class="font-semibold">
                    {if record.member && record.member.user, do: record.member.user.name, else: "Unknown"}
                  </p>
                  <p class="text-xs text-base-content/50 mt-1">
                    {format_datetime(record.attended_at)}
                    <%= if record.notes do %>
                      &middot; {record.notes}
                    <% end %>
                  </p>
                </div>
              </:mobile_card>
            </.data_table>
          <% end %>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
