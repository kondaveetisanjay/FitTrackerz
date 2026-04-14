defmodule FitTrackerz.Workers.InactivityReminderWorker do
  @moduledoc """
  Daily Oban worker (runs at 10:00 UTC) that:
  Finds active gym members with no workout or attendance activity in 5+ days
  and sends a gentle inactivity reminder notification (max once per 3 days).
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  import Ecto.Query

  alias FitTrackerz.Repo
  alias FitTrackerz.Notifications.Notification

  @inactivity_days 5
  @reminder_cooldown_days 3

  @impl Oban.Worker
  def perform(_job) do
    active_members = fetch_active_members()
    today = Date.utc_today()

    for member <- active_members do
      last_activity = last_activity_date(member.id)

      inactive? =
        is_nil(last_activity) ||
          Date.diff(today, last_activity) >= @inactivity_days

      if inactive? && !recently_reminded?(member.user_id) do
        send_inactivity_reminder(member)
      end
    end

    :ok
  end

  defp fetch_active_members do
    from(m in FitTrackerz.Gym.GymMember,
      join: u in FitTrackerz.Accounts.User,
      on: u.id == m.user_id,
      where: m.is_active == true,
      select: %{id: m.id, user_id: u.id, gym_id: m.gym_id, name: u.name}
    )
    |> Repo.all()
  end

  defp last_activity_date(gym_member_id) do
    last_workout =
      from(w in FitTrackerz.Training.WorkoutLog,
        where: w.member_id == ^gym_member_id,
        select: max(w.completed_on)
      )
      |> Repo.one()

    last_attendance =
      from(a in FitTrackerz.Training.AttendanceRecord,
        where: a.member_id == ^gym_member_id,
        select: max(fragment("?::date", a.attended_at))
      )
      |> Repo.one()

    case {last_workout, last_attendance} do
      {nil, nil} -> nil
      {w, nil} -> w
      {nil, a} -> a
      {w, a} -> if Date.compare(w, a) == :gt, do: w, else: a
    end
  end

  defp recently_reminded?(user_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -@reminder_cooldown_days * 24 * 60 * 60, :second)

    from(n in Notification,
      where:
        n.user_id == ^user_id and
          n.type == :inactivity_reminder and
          n.inserted_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp send_inactivity_reminder(member) do
    Ash.create!(
      Notification,
      %{
        type: :inactivity_reminder,
        title: "We miss you!",
        message:
          "Hey #{member.name}, you haven't checked in for a while. Come back and keep your streak going!",
        user_id: member.user_id,
        gym_id: member.gym_id,
        metadata: %{}
      },
      authorize?: false
    )

    Phoenix.PubSub.broadcast(
      FitTrackerz.PubSub,
      "notifications:#{member.user_id}",
      {:new_notification, %{type: :inactivity_reminder, title: "We miss you!"}}
    )
  end
end
