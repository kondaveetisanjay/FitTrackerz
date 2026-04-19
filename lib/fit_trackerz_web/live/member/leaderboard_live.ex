defmodule FitTrackerzWeb.Member.LeaderboardLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Gamification.Leaderboard

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
           page_title: "Leaderboard",
           no_gym: true,
           leaders: [],
           active_tab: :attendance,
           period: :month
         )}

      memberships ->
        membership = List.first(memberships)
        gym = membership.gym

        leaders = Leaderboard.attendance_leaders(gym.id, :month)

        {:ok,
         assign(socket,
           page_title: "Leaderboard",
           no_gym: false,
           membership: membership,
           gym: gym,
           leaders: leaders,
           active_tab: :attendance,
           period: :month
         )}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    socket = assign(socket, active_tab: tab) |> reload_leaders()
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    period = String.to_existing_atom(period)
    socket = assign(socket, period: period) |> reload_leaders()
    {:noreply, socket}
  end

  defp reload_leaders(socket) do
    %{gym: gym, active_tab: tab, period: period} = socket.assigns

    leaders =
      case tab do
        :attendance -> Leaderboard.attendance_leaders(gym.id, period)
        :workouts -> Leaderboard.workout_leaders(gym.id, period)
        :streaks -> Leaderboard.streak_leaders(gym.id)
      end

    assign(socket, leaders: leaders)
  end

  defp rank_icon(1), do: "text-yellow-500"
  defp rank_icon(2), do: "text-gray-400"
  defp rank_icon(3), do: "text-amber-700"
  defp rank_icon(_), do: "text-base-content/30"

  defp period_label(:week), do: "This Week"
  defp period_label(:month), do: "This Month"
  defp period_label(:all_time), do: "All Time"

  defp tab_label(:attendance), do: "Attendance"
  defp tab_label(:workouts), do: "Workouts"
  defp tab_label(:streaks), do: "Streaks"

  defp value_label(:attendance), do: "Check-ins"
  defp value_label(:workouts), do: "Workouts"
  defp value_label(:streaks), do: "Day Streak"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <.page_header title="Leaderboard" subtitle={"Rankings for #{if assigns[:gym], do: @gym.name, else: "your gym"}"} back_path="/member/dashboard" />

      <%= if @no_gym do %>
        <.empty_state icon="hero-building-office-2" title="No Gym Membership" subtitle="Join a gym to see leaderboards." />
      <% else %>
        <div class="space-y-4">
            <%!-- Tab buttons --%>
            <div class="flex gap-2">
              <%= for tab <- [:attendance, :workouts, :streaks] do %>
                <button
                  phx-click="switch_tab"
                  phx-value-tab={tab}
                  class={["btn btn-sm", if(@active_tab == tab, do: "btn-primary", else: "btn-ghost")]}
                >
                  {tab_label(tab)}
                </button>
              <% end %>
            </div>

            <%!-- Period selector (hidden for streaks) --%>
            <%= if @active_tab != :streaks do %>
              <div class="flex gap-1">
                <%= for period <- [:week, :month, :all_time] do %>
                  <button
                    phx-click="change_period"
                    phx-value-period={period}
                    class={["btn btn-xs", if(@period == period, do: "btn-secondary", else: "btn-ghost")]}
                  >
                    {period_label(period)}
                  </button>
                <% end %>
              </div>
            <% end %>

            <%!-- Leaderboard table --%>
            <.card padded={false} id="leaderboard-card">
              <%= if @leaders == [] do %>
                <.empty_state icon="hero-trophy" title="No Activity Yet" subtitle="Be the first to top the leaderboard!" />
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="text-base-content/40">
                        <th class="w-16">Rank</th>
                        <th>Member</th>
                        <th class="text-right">{value_label(@active_tab)}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for leader <- @leaders do %>
                        <tr class={[
                          "border-b border-base-300/30",
                          if(assigns[:membership] && leader.gym_member_id == @membership.id, do: "bg-primary/10")
                        ]}>
                          <td>
                            <%= if leader.rank <= 3 do %>
                              <span class={"font-bold text-lg #{rank_icon(leader.rank)}"}>{leader.rank}</span>
                            <% else %>
                              <span class="text-base-content/50">{leader.rank}</span>
                            <% end %>
                          </td>
                          <td>
                            <div class="flex items-center gap-2">
                              <.avatar name={leader.member_name} size="sm" />
                              <span class="font-medium">{leader.member_name}</span>
                            </div>
                          </td>
                          <td class="text-right font-bold">{leader.value}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </.card>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
