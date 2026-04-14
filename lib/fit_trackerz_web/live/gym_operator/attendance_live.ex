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
      <div class="space-y-6">
        <.page_header title="Attendance" subtitle="View attendance records for your gym." back_path="/gym" />

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before viewing attendance.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <.card title="Attendance Records" subtitle={"#{length(@records)} records"}>
            <%= if @records == [] do %>
              <.empty_state
                icon="hero-clipboard-document-check"
                title="No attendance records yet"
                subtitle="Attendance records will appear here once members start checking in."
              />
            <% else %>
              <.data_table id="attendance-table" rows={@records} row_id={fn record -> "attendance-#{record.id}" end}>
                <:col :let={record} label="Member">
                  <div class="flex items-center gap-2">
                    <.avatar name={get_member_name(record)} size="sm" />
                    <span class="font-medium">{get_member_name(record)}</span>
                  </div>
                </:col>
                <:col :let={record} label="Attended At">
                  {format_datetime(record.attended_at)}
                </:col>
                <:col :let={record} label="Notes">
                  <span class="text-base-content/60 text-sm max-w-xs truncate">{record.notes || "--"}</span>
                </:col>
                <:col :let={record} label="Marked By">
                  {get_marked_by_name(record)}
                </:col>
              </.data_table>
            <% end %>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
