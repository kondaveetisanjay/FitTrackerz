defmodule FitTrackerzWeb.Member.AttendanceLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "Attendance",
           memberships: [],
           attendance_records: [],
           total_count: 0,
           no_gym: true,
           gym_tier: :free
         )}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)

        attendance_records = case FitTrackerz.Training.list_attendance_by_member(member_ids, actor: actor, load: [:gym, :marked_by]) do
          {:ok, records} -> Enum.sort_by(records, & &1.attended_at, {:desc, DateTime})
          _ -> []
        end

        gym_tier =
          case memberships do
            [m | _] -> if m.gym, do: m.gym.tier, else: :free
            _ -> :free
          end

        {:ok,
         assign(socket,
           page_title: "Attendance",
           memberships: memberships,
           attendance_records: attendance_records,
           total_count: length(attendance_records),
           no_gym: false,
           gym_tier: gym_tier
         )}
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp this_month_count(records) do
    now = DateTime.utc_now()

    Enum.count(records, fn record ->
      record.attended_at.month == now.month and record.attended_at.year == now.year
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Attendance History" subtitle="Track your gym check-in history." back_path="/member">
        <:actions>
          <%= if @gym_tier == :premium do %>
            <.button variant="primary" size="sm" icon="hero-qr-code" navigate="/member/qr-code">
              My QR Code
            </.button>
          <% end %>
        </:actions>
      </.page_header>

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You haven't joined any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%!-- Stats --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6 mb-8">
          <.stat_card
            label="Total Attendance"
            value={@total_count}
            icon="hero-clipboard-document-check"
            color="primary"
          />
          <.stat_card
            label="Active Gyms"
            value={length(@memberships)}
            icon="hero-building-office-2"
            color="success"
          />
          <.stat_card
            label="This Month"
            value={this_month_count(@attendance_records)}
            icon="hero-calendar-days"
            color="info"
          />
        </div>

        <%= if @attendance_records == [] do %>
          <.empty_state
            icon="hero-clipboard-document-check"
            title="No Attendance Records"
            subtitle="No check-ins recorded yet. Visit your gym and check in to start tracking your attendance!"
          />
        <% else %>
          <.card title="Check-in History" id="attendance-table">
            <.data_table id="attendance" rows={@attendance_records}>
              <:col :let={record} label="Date">
                <span class="font-medium">{format_date(record.attended_at)}</span>
              </:col>
              <:col :let={record} label="Time">
                <span class="text-base-content/70">{format_time(record.attended_at)}</span>
              </:col>
              <:col :let={record} label="Gym">
                <%= if record.gym do %>
                  <span class="flex items-center gap-1">
                    <.icon name="hero-building-office-2-mini" class="size-3 text-base-content/40" />
                    {record.gym.name}
                  </span>
                <% else %>
                  <span class="text-base-content/30">--</span>
                <% end %>
              </:col>
              <:col :let={record} label="Marked By">
                <%= if record.marked_by do %>
                  {record.marked_by.name}
                <% else %>
                  <span class="text-base-content/30">--</span>
                <% end %>
              </:col>
              <:col :let={record} label="Notes">
                <span class="text-base-content/50 max-w-xs truncate block">
                  {record.notes || "--"}
                </span>
              </:col>
              <:mobile_card :let={record}>
                <div class="space-y-1">
                  <div class="flex items-center justify-between">
                    <span class="font-semibold">{format_date(record.attended_at)}</span>
                    <span class="text-sm text-base-content/60">{format_time(record.attended_at)}</span>
                  </div>
                  <%= if record.gym do %>
                    <p class="text-xs text-base-content/50">{record.gym.name}</p>
                  <% end %>
                </div>
              </:mobile_card>
            </.data_table>
          </.card>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
