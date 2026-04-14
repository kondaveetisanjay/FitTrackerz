defmodule FitTrackerz.Workers.StreakCalculationWorker do
  @moduledoc """
  Daily Oban worker (runs at midnight UTC) that:
  1. Calculates workout and attendance streaks for all active gym members
  2. Updates Gamification.Streak records (upsert)
  3. Fires streak milestone notifications (7/30/90/365 days) — idempotent
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query

  alias FitTrackerz.Repo
  alias FitTrackerz.Gamification.Streak
  alias FitTrackerz.Gamification.StreakMilestone
  alias FitTrackerz.Notifications.Notification

  @milestones [7, 30, 90, 365]

  @impl Oban.Worker
  def perform(_job) do
    active_members = fetch_active_members()

    for member <- active_members do
      process_member(member)
    end

    :ok
  end

  defp fetch_active_members do
    from(m in FitTrackerz.Gym.GymMember,
      join: u in FitTrackerz.Accounts.User,
      on: u.id == m.user_id,
      where: m.is_active == true,
      select: %{id: m.id, user_id: u.id, gym_id: m.gym_id}
    )
    |> Repo.all()
  end

  defp process_member(member) do
    workout_streak = calculate_workout_streak(member.id)
    attendance_streak = calculate_attendance_streak(member.id)

    upsert_streak(member.id, :workout, workout_streak)
    upsert_streak(member.id, :attendance, attendance_streak)

    check_milestones(member, :workout, workout_streak)
    check_milestones(member, :attendance, attendance_streak)
  end

  defp calculate_workout_streak(gym_member_id) do
    dates =
      from(w in FitTrackerz.Training.WorkoutLog,
        where: w.member_id == ^gym_member_id,
        where: w.completed_on >= ^Date.add(Date.utc_today(), -365),
        select: w.completed_on
      )
      |> Repo.all()
      |> MapSet.new()

    count_consecutive_days(dates)
  end

  defp calculate_attendance_streak(gym_member_id) do
    dates =
      from(a in FitTrackerz.Training.AttendanceRecord,
        where: a.member_id == ^gym_member_id,
        where: a.attended_at >= ^DateTime.add(DateTime.utc_now(), -365, :day),
        select: fragment("?::date", a.attended_at)
      )
      |> Repo.all()
      |> MapSet.new()

    count_consecutive_days(dates)
  end

  defp count_consecutive_days(dates_set) do
    today = Date.utc_today()

    Enum.reduce_while(0..364, 0, fn offset, acc ->
      date = Date.add(today, -offset)

      if MapSet.member?(dates_set, date) do
        {:cont, acc + 1}
      else
        {:halt, acc}
      end
    end)
  end

  defp upsert_streak(gym_member_id, streak_type, current_streak) do
    existing =
      from(s in Streak,
        where: s.gym_member_id == ^gym_member_id and s.streak_type == ^streak_type,
        select: s.longest_streak
      )
      |> Repo.one()

    longest = max(current_streak, existing || 0)
    last_activity = if current_streak > 0, do: Date.utc_today(), else: nil

    Ash.create!(
      Streak,
      %{
        gym_member_id: gym_member_id,
        streak_type: streak_type,
        current_streak: current_streak,
        longest_streak: longest,
        last_activity_date: last_activity
      },
      upsert?: true,
      upsert_identity: :unique_member_streak_type,
      upsert_fields: [:current_streak, :longest_streak, :last_activity_date, :updated_at],
      authorize?: false
    )
  end

  defp check_milestones(member, streak_type, current_streak) do
    for milestone <- @milestones, current_streak >= milestone do
      already_achieved =
        from(m in StreakMilestone,
          where:
            m.gym_member_id == ^member.id and
              m.streak_type == ^streak_type and
              m.milestone_days == ^milestone
        )
        |> Repo.exists?()

      unless already_achieved do
        Ash.create!(
          StreakMilestone,
          %{
            gym_member_id: member.id,
            streak_type: streak_type,
            milestone_days: milestone,
            achieved_at: DateTime.utc_now()
          },
          authorize?: false
        )

        streak_label = if streak_type == :workout, do: "workout", else: "attendance"

        Ash.create!(
          Notification,
          %{
            type: :streak_milestone,
            title: "#{milestone}-Day Streak!",
            message:
              "Congratulations! You've reached a #{milestone}-day #{streak_label} streak. Keep it up!",
            user_id: member.user_id,
            metadata: %{
              "streak_type" => to_string(streak_type),
              "milestone_days" => milestone,
              "current_streak" => to_string(current_streak)
            }
          },
          authorize?: false
        )

        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "notifications:#{member.user_id}",
          {:new_notification,
           %{type: :streak_milestone, title: "#{milestone}-Day Streak!", streak_type: streak_type}}
        )
      end
    end
  end
end
