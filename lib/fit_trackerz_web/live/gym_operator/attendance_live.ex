defmodule FitTrackerzWeb.GymOperator.AttendanceLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        members = case FitTrackerz.Gym.list_members_by_gym(gym.id, actor: actor) do
          {:ok, members} -> members
          _ -> []
        end

        member_ids = Enum.map(members, & &1.id)

        records = case FitTrackerz.Training.list_attendance_by_member(member_ids, actor: actor, load: [:marked_by, member: [:user]]) do
          {:ok, records} -> records
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "Attendance",
           gym: gym,
           records: records
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Attendance",
           gym: nil,
           records: []
         )}
    end
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp format_datetime(_), do: "--"

  defp get_member_name(%{member: %{user: %{name: name}}}), do: name
  defp get_member_name(_), do: "Unknown"

  defp get_marked_by_name(%{marked_by: %{name: name}}), do: name
  defp get_marked_by_name(_), do: "--"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Attendance</h1>
            <p class="text-base-content/50 mt-1">View attendance records for your gym.</p>
          </div>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before viewing attendance.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <div class="card bg-base-200/50 border border-base-300/50" id="attendance-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-clipboard-document-check-solid" class="size-5 text-success" />
                Attendance Records
                <span class="badge badge-neutral badge-sm">{length(@records)}</span>
              </h2>
              <%= if @records == [] do %>
                <div
                  class="flex flex-col items-center gap-3 p-8 rounded-lg bg-base-300/20"
                  id="no-attendance-state"
                >
                  <.icon name="hero-clipboard-document-check" class="size-12 text-base-content/20" />
                  <p class="text-base-content/50 font-medium">No attendance records yet</p>
                  <p class="text-sm text-base-content/40">
                    Attendance records will appear here once members start checking in.
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="attendance-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Member</th>
                        <th>Attended At</th>
                        <th>Notes</th>
                        <th>Marked By</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for record <- @records do %>
                        <tr id={"attendance-#{record.id}"}>
                          <td class="font-medium">{get_member_name(record)}</td>
                          <td class="text-base-content/60">{format_datetime(record.attended_at)}</td>
                          <td class="text-base-content/60 text-sm max-w-xs truncate">
                            {record.notes || "--"}
                          </td>
                          <td class="text-base-content/60">{get_marked_by_name(record)}</td>
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
