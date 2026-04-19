defmodule FitTrackerz.Gamification.Leaderboard do
  @moduledoc """
  On-demand leaderboard queries. Not an Ash resource — computes rankings
  directly from AttendanceRecord, WorkoutLog, and Streak data.

  All functions return a list of maps with keys:
    %{rank: integer, gym_member_id: uuid_string, member_name: string, value: integer}
  """

  import Ecto.Query

  alias FitTrackerz.Repo

  @top_n 10

  @doc """
  Top members by attendance count for the given gym and period.
  period: :week | :month | :all_time
  """
  def attendance_leaders(gym_id, period \\ :month) do
    since = period_start(period)

    from(m in FitTrackerz.Gym.GymMember,
      join: u in FitTrackerz.Accounts.User,
      on: u.id == m.user_id,
      join: a in FitTrackerz.Training.AttendanceRecord,
      on: a.member_id == m.id,
      where: m.gym_id == ^gym_id and m.is_active == true,
      where: a.attended_at >= ^since,
      group_by: [m.id, u.name],
      select: %{gym_member_id: m.id, member_name: u.name, value: count(a.id)},
      order_by: [desc: count(a.id)],
      limit: @top_n
    )
    |> Repo.all()
    |> add_rank()
  end

  @doc """
  Top members by workout log count for the given gym and period.
  period: :week | :month | :all_time
  """
  def workout_leaders(gym_id, period \\ :month) do
    since = period_start(period)

    from(m in FitTrackerz.Gym.GymMember,
      join: u in FitTrackerz.Accounts.User,
      on: u.id == m.user_id,
      join: w in FitTrackerz.Training.WorkoutLog,
      on: w.member_id == m.id,
      where: m.gym_id == ^gym_id and m.is_active == true,
      where: w.inserted_at >= ^since,
      group_by: [m.id, u.name],
      select: %{gym_member_id: m.id, member_name: u.name, value: count(w.id)},
      order_by: [desc: count(w.id)],
      limit: @top_n
    )
    |> Repo.all()
    |> add_rank()
  end

  @doc """
  Top members by current workout streak for the given gym.
  """
  def streak_leaders(gym_id) do
    from(m in FitTrackerz.Gym.GymMember,
      join: u in FitTrackerz.Accounts.User,
      on: u.id == m.user_id,
      join: s in FitTrackerz.Gamification.Streak,
      on: s.gym_member_id == m.id,
      where: m.gym_id == ^gym_id and m.is_active == true,
      where: s.streak_type == :workout,
      where: s.current_streak > 0,
      select: %{gym_member_id: m.id, member_name: u.name, value: s.current_streak},
      order_by: [desc: s.current_streak],
      limit: @top_n
    )
    |> Repo.all()
    |> add_rank()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp period_start(:week), do: DateTime.add(DateTime.utc_now(), -7, :day)
  defp period_start(:month), do: DateTime.add(DateTime.utc_now(), -30, :day)
  defp period_start(:all_time), do: ~U[2000-01-01 00:00:00Z]

  defp add_rank(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :rank, rank) end)
  end
end
