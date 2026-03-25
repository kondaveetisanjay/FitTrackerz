defmodule FitTrackerz.Analytics do
  @moduledoc """
  Analytics context module providing query functions for dashboard metrics.
  Uses schemaless Ecto queries against existing tables.
  """

  import Ecto.Query
  alias FitTrackerz.Repo

  # Schemaless queries need explicit UUID casting
  defmacrop uuid(value) do
    quote do: type(^unquote(value), Ecto.UUID)
  end

  # ---------------------------------------------------------------------------
  # 1. active_members_count/1
  # ---------------------------------------------------------------------------

  @doc "Count currently active members for a gym."
  def active_members_count(gym_id) do
    from(m in "gym_members",
      where: m.gym_id == uuid(gym_id) and m.is_active == true,
      select: count(m.id)
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # 2. active_members_count_as_of/2
  # ---------------------------------------------------------------------------

  @doc "Count active members who had joined on or before the given date."
  def active_members_count_as_of(gym_id, %Date{} = date) do
    from(m in "gym_members",
      where:
        m.gym_id == uuid(gym_id) and
          m.is_active == true and
          m.joined_at <= ^date,
      select: count(m.id)
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # 3. new_members/3
  # ---------------------------------------------------------------------------

  @doc "New members who joined within the date range, with daily breakdown."
  def new_members(gym_id, %Date{} = start_date, %Date{} = end_date) do
    daily_data =
      from(m in "gym_members",
        where:
          m.gym_id == uuid(gym_id) and
            m.joined_at >= ^start_date and
            m.joined_at <= ^end_date,
        group_by: m.joined_at,
        select: {m.joined_at, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)

    %{total: total, daily: daily}
  end

  # ---------------------------------------------------------------------------
  # 4. revenue/3
  # ---------------------------------------------------------------------------

  @doc "Revenue from paid subscriptions within the date range, with daily breakdown."
  def revenue(gym_id, %Date{} = start_date, %Date{} = end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    daily_data =
      from(ms in "member_subscriptions",
        join: sp in "subscription_plans",
        on: ms.subscription_plan_id == sp.id,
        where:
          ms.gym_id == uuid(gym_id) and
            ms.payment_status == ^"paid" and
            ms.inserted_at >= ^start_dt and
            ms.inserted_at <= ^end_dt,
        group_by: fragment("?::date", ms.inserted_at),
        select:
          {fragment("?::date", ms.inserted_at),
           coalesce(sum(sp.price_in_paise), 0)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)

    %{total: total, daily: daily}
  end

  # ---------------------------------------------------------------------------
  # 5. attendance_trend/3
  # ---------------------------------------------------------------------------

  @doc "Attendance counts within the date range, with daily breakdown and average."
  def attendance_trend(gym_id, %Date{} = start_date, %Date{} = end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    daily_data =
      from(a in "attendance_records",
        where:
          a.gym_id == uuid(gym_id) and
            a.attended_at >= ^start_dt and
            a.attended_at <= ^end_dt,
        group_by: fragment("?::date", a.attended_at),
        select:
          {fragment("?::date", a.attended_at), count(a.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    days_in_range = max(Date.diff(end_date, start_date) + 1, 1)
    avg_daily = total / days_in_range

    %{total: total, avg_daily: avg_daily, daily: daily}
  end

  # ---------------------------------------------------------------------------
  # 6. subscription_breakdown/1
  # ---------------------------------------------------------------------------

  @doc "Count of member subscriptions grouped by status for a gym."
  def subscription_breakdown(gym_id) do
    from(ms in "member_subscriptions",
      where: ms.gym_id == uuid(gym_id),
      group_by: ms.status,
      select: {ms.status, count(ms.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # 7. payment_collection/3
  # ---------------------------------------------------------------------------

  @doc "Count of member subscriptions grouped by payment_status within the date range."
  def payment_collection(gym_id, %Date{} = start_date, %Date{} = end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    from(ms in "member_subscriptions",
      where:
        ms.gym_id == uuid(gym_id) and
          ms.inserted_at >= ^start_dt and
          ms.inserted_at <= ^end_dt,
      group_by: ms.payment_status,
      select: {ms.payment_status, count(ms.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # 8. class_utilization/3
  # ---------------------------------------------------------------------------

  @doc "Class utilization: bookings vs capacity for each class within the date range."
  def class_utilization(gym_id, %Date{} = start_date, %Date{} = end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    from(sc in "scheduled_classes",
      join: cd in "class_definitions",
      on: sc.class_definition_id == cd.id,
      join: gb in "gym_branches",
      on: sc.branch_id == gb.id,
      left_join: cb in "class_bookings",
      on:
        cb.scheduled_class_id == sc.id and
          cb.status in ^["pending", "confirmed"],
      where:
        gb.gym_id == uuid(gym_id) and
          sc.scheduled_at >= ^start_dt and
          sc.scheduled_at <= ^end_dt,
      group_by: [cd.name, cd.max_participants],
      select: %{
        class_name: cd.name,
        bookings: count(cb.id),
        capacity: cd.max_participants
      }
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # 9. member_retention/3
  # ---------------------------------------------------------------------------

  @doc "Daily running totals of active and inactive members over the date range."
  def member_retention(gym_id, %Date{} = start_date, %Date{} = end_date) do
    # Base counts before the start_date
    base_active =
      from(m in "gym_members",
        where:
          m.gym_id == uuid(gym_id) and
            m.joined_at < ^start_date and
            m.is_active == true,
        select: count(m.id)
      )
      |> Repo.one()

    base_inactive =
      from(m in "gym_members",
        where:
          m.gym_id == uuid(gym_id) and
            m.joined_at < ^start_date and
            m.is_active == false,
        select: count(m.id)
      )
      |> Repo.one()

    # New joins per day within the range
    daily_joins =
      from(m in "gym_members",
        where:
          m.gym_id == uuid(gym_id) and
            m.joined_at >= ^start_date and
            m.joined_at <= ^end_date,
        group_by: m.joined_at,
        select: {m.joined_at, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    # Build running totals
    date_range(start_date, end_date)
    |> Enum.scan(
      %{date: nil, active: base_active, inactive: base_inactive},
      fn date, acc ->
        new_joins = Map.get(daily_joins, date, 0)
        %{date: date, active: acc.active + new_joins, inactive: acc.inactive}
      end
    )
  end

  # ===========================================================================
  # Admin / Platform-wide analytics
  # ===========================================================================

  def total_gyms_count do
    from(g in "gyms", select: count(g.id)) |> Repo.one()
  end

  def gyms_by_status do
    from(g in "gyms", group_by: g.status, select: {g.status, count(g.id)})
    |> Repo.all()
    |> Map.new()
  end

  def total_members_count do
    from(m in "gym_members", where: m.is_active == true, select: count(m.id)) |> Repo.one()
  end

  def total_trainers_count do
    from(t in "gym_trainers", where: t.is_active == true, select: count(t.id)) |> Repo.one()
  end

  def platform_revenue(start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    daily_data =
      from(ms in "member_subscriptions",
        join: sp in "subscription_plans", on: ms.subscription_plan_id == sp.id,
        where: ms.payment_status == ^"paid" and ms.inserted_at >= ^start_dt and ms.inserted_at <= ^end_dt,
        group_by: fragment("?::date", ms.inserted_at),
        select: {fragment("?::date", ms.inserted_at), coalesce(sum(sp.price_in_paise), 0)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_new_gyms(start_date, end_date) do
    daily_data =
      from(g in "gyms",
        where: fragment("?::date", g.inserted_at) >= ^start_date and fragment("?::date", g.inserted_at) <= ^end_date,
        group_by: fragment("?::date", g.inserted_at),
        select: {fragment("?::date", g.inserted_at), count(g.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_member_growth(start_date, end_date) do
    daily_data =
      from(m in "gym_members",
        where: m.joined_at >= ^start_date and m.joined_at <= ^end_date,
        group_by: m.joined_at,
        select: {m.joined_at, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_subscription_breakdown do
    from(ms in "member_subscriptions", group_by: ms.status, select: {ms.status, count(ms.id)})
    |> Repo.all()
    |> Map.new()
  end

  def top_gyms_by_members(limit \\ 10) do
    from(gm in "gym_members",
      join: g in "gyms", on: gm.gym_id == g.id,
      where: gm.is_active == true,
      group_by: [g.id, g.name],
      select: %{gym_name: g.name, member_count: count(gm.id)},
      order_by: [desc: count(gm.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fill_missing_dates(data_map, start_date, end_date) do
    date_range(start_date, end_date)
    |> Enum.map(fn date ->
      value = Map.get(data_map, date, 0)
      %{date: date, value: to_integer(value)}
    end)
  end

  defp to_integer(%Decimal{} = d), do: Decimal.to_integer(d)
  defp to_integer(v) when is_integer(v), do: v
  defp to_integer(v) when is_float(v), do: round(v)
  defp to_integer(_), do: 0

  defp date_range(%Date{} = start_date, %Date{} = end_date) do
    Date.range(start_date, end_date) |> Enum.to_list()
  end

  defp to_start_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  defp to_end_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end
end
