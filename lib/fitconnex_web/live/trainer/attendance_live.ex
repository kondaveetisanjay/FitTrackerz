defmodule FitconnexWeb.Trainer.AttendanceLive do
  use FitconnexWeb, :live_view

  alias FitconnexWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym_trainers = case Fitconnex.Gym.list_active_trainerships(actor.id, actor: actor, load: [:gym]) do
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

      clients = case Fitconnex.Gym.list_members_by_trainer(trainer_ids, actor: actor, load: [:user, :gym]) do
        {:ok, members} -> members
        _ -> []
      end

      member_ids = Enum.map(clients, & &1.id)

      records = case Fitconnex.Training.list_attendance_by_member(member_ids, actor: actor, load: [:gym, member: [:user]]) do
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

      case Fitconnex.Training.create_attendance(%{
        attended_at: attended_at,
        notes: params["notes"],
        member_id: client.id,
        gym_id: client.gym_id,
        marked_by_id: actor.id
      }, actor: actor) do
        {:ok, _record} ->
          records = case Fitconnex.Training.list_attendance_by_member(client_ids, actor: actor, load: [:gym, member: [:user]]) do
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
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Attendance</h1>
              <p class="text-base-content/50 mt-1">Track and manage client attendance records.</p>
            </div>
          </div>
          <%= unless @no_gym do %>
            <button
              class="btn btn-primary btn-sm gap-2 font-semibold"
              phx-click="toggle_form"
              id="toggle-attendance-form-btn"
            >
              <.icon name="hero-plus-mini" class="size-4" /> Mark Attendance
            </button>
          <% end %>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-notice">
            <div class="card-body p-8 items-center text-center">
              <div class="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-exclamation-triangle-solid" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Association</h2>
              <p class="text-base-content/50 mt-2 max-w-md">
                You haven't been added to any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Stats --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-total-records">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Total Records
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@records)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon name="hero-clipboard-document-check-solid" class="size-6 text-primary" />
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-clients-tracked">
              <div class="card-body p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Clients Tracked
                    </p>
                    <p class="text-3xl font-black mt-1">{length(@clients)}</p>
                  </div>
                  <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-user-group-solid" class="size-6 text-info" />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Mark Attendance Form --%>
          <%= if @show_form do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="attendance-form-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2">
                  <.icon name="hero-clipboard-document-check-solid" class="size-5 text-primary" />
                  Mark Attendance
                </h2>
                <.form
                  for={@form}
                  id="attendance-form"
                  phx-change="validate"
                  phx-submit="save_attendance"
                  class="mt-4 space-y-4"
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
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="toggle_form"
                      id="cancel-attendance-btn"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="btn btn-primary btn-sm gap-2"
                      id="submit-attendance-btn"
                    >
                      <.icon name="hero-check-mini" class="size-4" /> Mark Present
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Attendance Records Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="attendance-table-card">
            <div class="card-body p-5">
              <h2 class="text-lg font-bold flex items-center gap-2">
                <.icon name="hero-clipboard-document-list-solid" class="size-5 text-accent" />
                Attendance Records
              </h2>
              <div class="mt-4 overflow-x-auto">
                <table class="table table-sm" id="attendance-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Member</th>
                      <th>Gym</th>
                      <th>Attended At</th>
                      <th>Notes</th>
                      <th>Recorded</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @records == [] do %>
                      <tr id="attendance-empty-row">
                        <td colspan="5" class="text-center text-base-content/40 py-8">
                          No attendance records yet. Use the form above to start marking attendance.
                        </td>
                      </tr>
                    <% else %>
                      <tr :for={record <- @records} id={"attendance-row-#{record.id}"}>
                        <td class="font-medium">
                          {if record.member && record.member.user, do: record.member.user.name, else: "Unknown"}
                        </td>
                        <td class="text-base-content/60">
                          {if record.gym, do: record.gym.name, else: "N/A"}
                        </td>
                        <td class="text-base-content/60">
                          {format_datetime(record.attended_at)}
                        </td>
                        <td class="text-base-content/60 max-w-xs truncate">
                          {record.notes || "-"}
                        </td>
                        <td class="text-base-content/40 text-xs">
                          {format_datetime(record.inserted_at)}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
