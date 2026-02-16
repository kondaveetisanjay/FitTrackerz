defmodule FitconnexWeb.Member.AttendanceLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case Fitconnex.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym, :assigned_trainer]) do
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
           no_gym: true
         )}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)

        attendance_records = case Fitconnex.Training.list_attendance_by_member(member_ids, actor: actor, load: [:gym, :marked_by]) do
          {:ok, records} -> Enum.sort_by(records, & &1.attended_at, {:desc, DateTime})
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "Attendance",
           memberships: memberships,
           attendance_records: attendance_records,
           total_count: length(attendance_records),
           no_gym: false
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
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-black tracking-tight">Attendance History</h1>
              <p class="text-base-content/50 mt-1">Track your gym check-in history.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <%!-- No Gym Membership --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You haven't joined any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Stats Card --%>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-total-attendance">
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Total Attendance
                    </p>
                    <p class="text-2xl sm:text-3xl font-black mt-1">{@total_count}</p>
                  </div>
                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                    <.icon
                      name="hero-clipboard-document-check-solid"
                      class="size-5 sm:size-6 text-primary"
                    />
                  </div>
                </div>
                <p class="text-xs text-base-content/40 mt-2">All time check-ins</p>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-gyms-count">
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Active Gyms
                    </p>
                    <p class="text-2xl sm:text-3xl font-black mt-1">{length(@memberships)}</p>
                  </div>
                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-success/10 flex items-center justify-center">
                    <.icon name="hero-building-office-2-solid" class="size-5 sm:size-6 text-success" />
                  </div>
                </div>
                <p class="text-xs text-base-content/40 mt-2">Gym memberships</p>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300/50" id="stat-this-month">
              <div class="card-body p-4 sm:p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      This Month
                    </p>
                    <p class="text-2xl sm:text-3xl font-black mt-1">
                      {this_month_count(@attendance_records)}
                    </p>
                  </div>
                  <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-info/10 flex items-center justify-center">
                    <.icon name="hero-calendar-days-solid" class="size-5 sm:size-6 text-info" />
                  </div>
                </div>
                <p class="text-xs text-base-content/40 mt-2">Check-ins this month</p>
              </div>
            </div>
          </div>

          <%= if @attendance_records == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-attendance">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
                  <.icon name="hero-clipboard-document-check" class="size-8 text-primary" />
                </div>
                <h2 class="text-lg font-bold">No Attendance Records</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  No check-ins recorded yet. Visit your gym and check in to start tracking your attendance!
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Attendance Table --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="attendance-table">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-clipboard-document-check-solid" class="size-5 text-primary" />
                  Check-in History
                </h2>
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Date</th>
                        <th>Time</th>
                        <th>Gym</th>
                        <th>Marked By</th>
                        <th>Notes</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={record <- @attendance_records} id={"attendance-#{record.id}"}>
                        <td class="font-medium">
                          {format_date(record.attended_at)}
                        </td>
                        <td class="text-base-content/70">
                          {format_time(record.attended_at)}
                        </td>
                        <td class="text-base-content/70">
                          <%= if record.gym do %>
                            <span class="flex items-center gap-1">
                              <.icon
                                name="hero-building-office-2-mini"
                                class="size-3 text-base-content/40"
                              />
                              {record.gym.name}
                            </span>
                          <% else %>
                            <span class="text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td class="text-base-content/70">
                          <%= if record.marked_by do %>
                            {record.marked_by.name}
                          <% else %>
                            <span class="text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td class="text-base-content/50 max-w-xs truncate">
                          {record.notes || "--"}
                        </td>
                      </tr>
                    </tbody>
                  </table>
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
