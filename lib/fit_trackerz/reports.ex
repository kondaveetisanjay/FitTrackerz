defmodule FitTrackerz.Reports do
  @moduledoc """
  Reports context module providing detailed report functions for operators and trainers.
  Uses schemaless Ecto queries against existing tables.

  Every report function returns:
    %{
      summary: [%{label: "...", value: ...}, ...],
      rows: [...],       # paginated
      total_count: N,
      columns: [%{key: :field, label: "Label"}, ...]
    }

  Each report also has a CSV variant (*_csv) returning a CSV string.
  """

  import Ecto.Query
  alias FitTrackerz.Repo

  # Schemaless queries need explicit UUID casting
  defmacrop uuid(value) do
    quote do: type(^unquote(value), Ecto.UUID)
  end

  # ===========================================================================
  # OPERATOR MEMBER REPORTS (1-8)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # 1. active_members_report
  # ---------------------------------------------------------------------------

  @doc "Report of all members with active/inactive status and assigned trainer."
  def active_members_report(gym_id, _start_date, _end_date, opts \\ []) do
    base_query = active_members_base_query(gym_id)

    summary_data =
      from([m, _u, _gt, _tu] in base_query,
        group_by: m.is_active,
        select: {m.is_active, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    active = Map.get(summary_data, true, 0)
    inactive = Map.get(summary_data, false, 0)

    summary = [
      %{label: "Active", value: active},
      %{label: "Inactive", value: inactive},
      %{label: "Total", value: active + inactive}
    ]

    total_count = active + inactive

    rows =
      from([m, u, _gt, tu] in base_query,
        order_by: [asc: u.name],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          joined_at: m.joined_at,
          trainer_name: tu.name
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | status: if(row.status, do: "Active", else: "Inactive")}
      end)

    columns = [
      %{key: :name, label: "Name"},
      %{key: :email, label: "Email"},
      %{key: :phone, label: "Phone"},
      %{key: :status, label: "Status"},
      %{key: :joined_at, label: "Joined At"},
      %{key: :trainer_name, label: "Trainer"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def active_members_report_csv(gym_id, start_date, end_date, opts \\ []) do
    base_query = active_members_base_query(gym_id)

    %{summary: summary, columns: columns} =
      active_members_report(gym_id, start_date, end_date, opts)

    rows =
      from([m, u, _gt, tu] in base_query,
        order_by: [asc: u.name],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          joined_at: m.joined_at,
          trainer_name: tu.name
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | status: if(row.status, do: "Active", else: "Inactive")}
      end)

    to_csv(summary, columns, rows)
  end

  defp active_members_base_query(gym_id) do
    from(m in "gym_members",
      join: u in "users",
      on: m.user_id == u.id,
      left_join: gt in "gym_trainers",
      on: m.assigned_trainer_id == gt.id,
      left_join: tu in "users",
      on: gt.user_id == tu.id,
      where: m.gym_id == uuid(gym_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 2. new_members_report
  # ---------------------------------------------------------------------------

  @doc "Report of members who joined within the date range."
  def new_members_report(gym_id, start_date, end_date, opts \\ []) do
    base_query = new_members_base_query(gym_id, start_date, end_date)

    total_count =
      from([m, _u] in base_query, select: count(m.id))
      |> Repo.one()

    summary = [%{label: "Total New Members", value: total_count}]

    rows =
      from([m, u] in base_query,
        order_by: [desc: m.joined_at],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          joined_at: m.joined_at
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :name, label: "Name"},
      %{key: :email, label: "Email"},
      %{key: :phone, label: "Phone"},
      %{key: :joined_at, label: "Joined At"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def new_members_report_csv(gym_id, start_date, end_date, opts \\ []) do
    base_query = new_members_base_query(gym_id, start_date, end_date)

    %{summary: summary, columns: columns} =
      new_members_report(gym_id, start_date, end_date, opts)

    rows =
      from([m, u] in base_query,
        order_by: [desc: m.joined_at],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          joined_at: m.joined_at
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp new_members_base_query(gym_id, start_date, end_date) do
    from(m in "gym_members",
      join: u in "users",
      on: m.user_id == u.id,
      where:
        m.gym_id == uuid(gym_id) and
          m.joined_at >= ^start_date and
          m.joined_at <= ^end_date
    )
  end

  # ---------------------------------------------------------------------------
  # 3. revenue_report
  # ---------------------------------------------------------------------------

  @doc "Revenue report from paid subscriptions within the date range."
  def revenue_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = revenue_base_query(gym_id, start_dt, end_dt)

    plan_totals =
      from([ms, sp, _m, _u] in base_query,
        group_by: sp.name,
        select: {sp.name, sum(sp.price_in_paise)}
      )
      |> Repo.all()

    grand_total =
      plan_totals
      |> Enum.reduce(0, fn {_name, amount}, acc -> acc + decimal_to_int(amount) end)

    summary =
      Enum.map(plan_totals, fn {name, amount} ->
        %{label: name, value: format_currency(decimal_to_int(amount))}
      end) ++ [%{label: "Grand Total", value: format_currency(grand_total)}]

    total_count =
      from([ms, _sp, _m, _u] in base_query, select: count(ms.id))
      |> Repo.one()

    rows =
      from([ms, sp, _m, u] in base_query,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_name: u.name,
          plan_name: sp.name,
          amount: sp.price_in_paise,
          payment_status: ms.payment_status,
          date: fragment("?::date", ms.inserted_at)
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | amount: format_currency(decimal_to_int(row.amount))}
      end)

    columns = [
      %{key: :member_name, label: "Member"},
      %{key: :plan_name, label: "Plan"},
      %{key: :amount, label: "Amount"},
      %{key: :payment_status, label: "Payment Status"},
      %{key: :date, label: "Date"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def revenue_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = revenue_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      revenue_report(gym_id, start_date, end_date, opts)

    rows =
      from([ms, sp, _m, u] in base_query,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_name: u.name,
          plan_name: sp.name,
          amount: sp.price_in_paise,
          payment_status: ms.payment_status,
          date: fragment("?::date", ms.inserted_at)
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | amount: format_currency(decimal_to_int(row.amount))}
      end)

    to_csv(summary, columns, rows)
  end

  defp revenue_base_query(gym_id, start_dt, end_dt) do
    from(ms in "member_subscriptions",
      join: sp in "subscription_plans",
      on: ms.subscription_plan_id == sp.id,
      join: m in "gym_members",
      on: ms.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      where:
        ms.gym_id == uuid(gym_id) and
          ms.payment_status == ^"paid" and
          ms.inserted_at >= ^start_dt and
          ms.inserted_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 4. attendance_report
  # ---------------------------------------------------------------------------

  @doc "Attendance report with check-in details within the date range."
  def attendance_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = attendance_base_query(gym_id, start_dt, end_dt)

    total_count =
      from([a, _m, _u, _mu] in base_query, select: count(a.id))
      |> Repo.one()

    days_in_range = max(Date.diff(end_date, start_date) + 1, 1)
    avg_daily = if total_count > 0, do: Float.round(total_count / days_in_range, 1), else: 0.0

    summary = [
      %{label: "Total Check-ins", value: total_count},
      %{label: "Avg Daily", value: avg_daily}
    ]

    rows =
      from([a, _m, u, mu] in base_query,
        order_by: [desc: a.attended_at],
        select: %{
          member_name: u.name,
          email: u.email,
          date: fragment("?::date", a.attended_at),
          time: fragment("to_char(?, 'HH24:MI')", a.attended_at),
          marked_by: mu.name
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :member_name, label: "Member"},
      %{key: :email, label: "Email"},
      %{key: :date, label: "Date"},
      %{key: :time, label: "Time"},
      %{key: :marked_by, label: "Marked By"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def attendance_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = attendance_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      attendance_report(gym_id, start_date, end_date, opts)

    rows =
      from([a, _m, u, mu] in base_query,
        order_by: [desc: a.attended_at],
        select: %{
          member_name: u.name,
          email: u.email,
          date: fragment("?::date", a.attended_at),
          time: fragment("to_char(?, 'HH24:MI')", a.attended_at),
          marked_by: mu.name
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp attendance_base_query(gym_id, start_dt, end_dt) do
    from(a in "attendance_records",
      join: m in "gym_members",
      on: a.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      left_join: mu in "users",
      on: a.marked_by_id == mu.id,
      where:
        a.gym_id == uuid(gym_id) and
          a.attended_at >= ^start_dt and
          a.attended_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 5. subscription_status_report
  # ---------------------------------------------------------------------------

  @doc "Report of subscriptions grouped by status."
  def subscription_status_report(gym_id, _start_date, _end_date, opts \\ []) do
    base_query = subscription_status_base_query(gym_id)

    status_counts =
      from([ms, _m, _u, _sp] in base_query,
        group_by: ms.status,
        select: {ms.status, count(ms.id)}
      )
      |> Repo.all()
      |> Map.new()

    active = Map.get(status_counts, "active", 0)
    expired = Map.get(status_counts, "expired", 0)
    cancelled = Map.get(status_counts, "cancelled", 0)

    summary = [
      %{label: "Active", value: active},
      %{label: "Expired", value: expired},
      %{label: "Cancelled", value: cancelled}
    ]

    total_count = active + expired + cancelled

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [asc: u.name],
        select: %{
          member_name: u.name,
          email: u.email,
          plan_name: sp.name,
          status: ms.status,
          starts_at: ms.starts_at,
          ends_at: ms.ends_at,
          payment_status: ms.payment_status
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :member_name, label: "Member"},
      %{key: :email, label: "Email"},
      %{key: :plan_name, label: "Plan"},
      %{key: :status, label: "Status"},
      %{key: :starts_at, label: "Starts At"},
      %{key: :ends_at, label: "Ends At"},
      %{key: :payment_status, label: "Payment Status"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def subscription_status_report_csv(gym_id, start_date, end_date, opts \\ []) do
    base_query = subscription_status_base_query(gym_id)

    %{summary: summary, columns: columns} =
      subscription_status_report(gym_id, start_date, end_date, opts)

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [asc: u.name],
        select: %{
          member_name: u.name,
          email: u.email,
          plan_name: sp.name,
          status: ms.status,
          starts_at: ms.starts_at,
          ends_at: ms.ends_at,
          payment_status: ms.payment_status
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp subscription_status_base_query(gym_id) do
    from(ms in "member_subscriptions",
      join: m in "gym_members",
      on: ms.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      join: sp in "subscription_plans",
      on: ms.subscription_plan_id == sp.id,
      where: ms.gym_id == uuid(gym_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 6. class_utilization_report
  # ---------------------------------------------------------------------------

  @doc "Class utilization report showing bookings vs capacity."
  def class_utilization_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = class_utilization_base_query(gym_id, start_dt, end_dt)

    # Summary: per class -> bookings / capacity
    class_summary =
      from([cb, sc, cd, _gb, _m, _u] in base_query,
        group_by: [cd.name, cd.max_participants],
        select: {cd.name, count(cb.id), cd.max_participants}
      )
      |> Repo.all()

    summary =
      Enum.map(class_summary, fn {name, bookings, capacity} ->
        %{label: name, value: "#{bookings} / #{capacity}"}
      end)

    total_count =
      from([cb, _sc, _cd, _gb, _m, _u] in base_query, select: count(cb.id))
      |> Repo.one()

    rows =
      from([cb, sc, cd, _gb, _m, u] in base_query,
        order_by: [desc: sc.scheduled_at],
        select: %{
          class_name: cd.name,
          member_name: u.name,
          booking_status: cb.status,
          scheduled_date: fragment("?::date", sc.scheduled_at)
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :class_name, label: "Class"},
      %{key: :member_name, label: "Member"},
      %{key: :booking_status, label: "Booking Status"},
      %{key: :scheduled_date, label: "Scheduled Date"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def class_utilization_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = class_utilization_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      class_utilization_report(gym_id, start_date, end_date, opts)

    rows =
      from([cb, sc, cd, _gb, _m, u] in base_query,
        order_by: [desc: sc.scheduled_at],
        select: %{
          class_name: cd.name,
          member_name: u.name,
          booking_status: cb.status,
          scheduled_date: fragment("?::date", sc.scheduled_at)
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp class_utilization_base_query(gym_id, start_dt, end_dt) do
    from(cb in "class_bookings",
      join: sc in "scheduled_classes",
      on: cb.scheduled_class_id == sc.id,
      join: cd in "class_definitions",
      on: sc.class_definition_id == cd.id,
      join: gb in "gym_branches",
      on: sc.branch_id == gb.id,
      join: m in "gym_members",
      on: cb.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      where:
        gb.gym_id == uuid(gym_id) and
          sc.scheduled_at >= ^start_dt and
          sc.scheduled_at <= ^end_dt and
          cb.status in ^["pending", "confirmed"]
    )
  end

  # ---------------------------------------------------------------------------
  # 7. payment_collection_report
  # ---------------------------------------------------------------------------

  @doc "Payment collection report grouped by payment status."
  def payment_collection_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = payment_collection_base_query(gym_id, start_dt, end_dt)

    status_data =
      from([ms, _m, _u, sp] in base_query,
        group_by: ms.payment_status,
        select: {ms.payment_status, count(ms.id), coalesce(sum(sp.price_in_paise), 0)}
      )
      |> Repo.all()
      |> Map.new(fn {status, count, amount} -> {status, {count, decimal_to_int(amount)}} end)

    {paid_count, paid_amount} = Map.get(status_data, "paid", {0, 0})
    {pending_count, _} = Map.get(status_data, "pending", {0, 0})
    {failed_count, _} = Map.get(status_data, "failed", {0, 0})
    {refunded_count, _} = Map.get(status_data, "refunded", {0, 0})

    summary = [
      %{label: "Paid", value: "#{paid_count} (#{format_currency(paid_amount)})"},
      %{label: "Pending", value: pending_count},
      %{label: "Failed", value: failed_count},
      %{label: "Refunded", value: refunded_count}
    ]

    total_count =
      from([ms, _m, _u, _sp] in base_query, select: count(ms.id))
      |> Repo.one()

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_name: u.name,
          plan_name: sp.name,
          amount: sp.price_in_paise,
          payment_status: ms.payment_status,
          date: fragment("?::date", ms.inserted_at)
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | amount: format_currency(decimal_to_int(row.amount))}
      end)

    columns = [
      %{key: :member_name, label: "Member"},
      %{key: :plan_name, label: "Plan"},
      %{key: :amount, label: "Amount"},
      %{key: :payment_status, label: "Payment Status"},
      %{key: :date, label: "Date"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def payment_collection_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = payment_collection_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      payment_collection_report(gym_id, start_date, end_date, opts)

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_name: u.name,
          plan_name: sp.name,
          amount: sp.price_in_paise,
          payment_status: ms.payment_status,
          date: fragment("?::date", ms.inserted_at)
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | amount: format_currency(decimal_to_int(row.amount))}
      end)

    to_csv(summary, columns, rows)
  end

  defp payment_collection_base_query(gym_id, start_dt, end_dt) do
    from(ms in "member_subscriptions",
      join: m in "gym_members",
      on: ms.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      join: sp in "subscription_plans",
      on: ms.subscription_plan_id == sp.id,
      where:
        ms.gym_id == uuid(gym_id) and
          ms.inserted_at >= ^start_dt and
          ms.inserted_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 8. member_retention_report
  # ---------------------------------------------------------------------------

  @doc "Member retention report with last attendance date."
  def member_retention_report(gym_id, _start_date, _end_date, opts \\ []) do
    base_query = member_retention_base_query(gym_id)

    status_counts =
      from([m, _u] in member_retention_count_query(gym_id),
        group_by: m.is_active,
        select: {m.is_active, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    active = Map.get(status_counts, true, 0)
    churned = Map.get(status_counts, false, 0)
    total = active + churned

    retention_rate =
      if total > 0,
        do: Float.round(active / total * 100, 1),
        else: 0.0

    summary = [
      %{label: "Active", value: active},
      %{label: "Churned", value: churned},
      %{label: "Retention Rate", value: "#{retention_rate}%"}
    ]

    rows =
      from([m, u, la] in base_query,
        order_by: [asc: u.name],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          joined_at: m.joined_at,
          last_attendance: la.last_date
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | status: if(row.status, do: "Active", else: "Inactive")}
      end)

    columns = [
      %{key: :name, label: "Name"},
      %{key: :email, label: "Email"},
      %{key: :phone, label: "Phone"},
      %{key: :status, label: "Status"},
      %{key: :joined_at, label: "Joined At"},
      %{key: :last_attendance, label: "Last Attendance"}
    ]

    %{summary: summary, rows: rows, total_count: total, columns: columns}
  end

  def member_retention_report_csv(gym_id, start_date, end_date, opts \\ []) do
    base_query = member_retention_base_query(gym_id)

    %{summary: summary, columns: columns} =
      member_retention_report(gym_id, start_date, end_date, opts)

    rows =
      from([m, u, la] in base_query,
        order_by: [asc: u.name],
        select: %{
          name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          joined_at: m.joined_at,
          last_attendance: la.last_date
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | status: if(row.status, do: "Active", else: "Inactive")}
      end)

    to_csv(summary, columns, rows)
  end

  defp member_retention_count_query(gym_id) do
    from(m in "gym_members",
      join: u in "users",
      on: m.user_id == u.id,
      where: m.gym_id == uuid(gym_id)
    )
  end

  defp member_retention_base_query(gym_id) do
    last_attendance_subquery =
      from(a in "attendance_records",
        group_by: a.member_id,
        select: %{
          member_id: a.member_id,
          last_date: max(fragment("?::date", a.attended_at))
        }
      )

    from(m in "gym_members",
      join: u in "users",
      on: m.user_id == u.id,
      left_join: la in subquery(last_attendance_subquery),
      on: la.member_id == m.id,
      where: m.gym_id == uuid(gym_id)
    )
  end

  # ===========================================================================
  # OPERATOR TRAINER PERFORMANCE REPORTS (9-12)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # 9. trainer_overview_report
  # ---------------------------------------------------------------------------

  @doc "Overview of all trainers with client counts, classes taught, and attendance marked."
  def trainer_overview_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    base_query = trainer_overview_base_query(gym_id, start_dt, end_dt)

    # Summary counts
    total_trainers =
      from(gt in "gym_trainers",
        where: gt.gym_id == uuid(gym_id) and gt.is_active == true,
        select: count(gt.id)
      )
      |> Repo.one()

    total_clients =
      from(m in "gym_members",
        join: gt in "gym_trainers",
        on: m.assigned_trainer_id == gt.id,
        where: m.gym_id == uuid(gym_id) and not is_nil(m.assigned_trainer_id),
        select: count(m.id)
      )
      |> Repo.one()

    total_classes =
      from(sc in "scheduled_classes",
        join: gb in "gym_branches",
        on: sc.branch_id == gb.id,
        where:
          gb.gym_id == uuid(gym_id) and
            sc.scheduled_at >= ^start_dt and
            sc.scheduled_at <= ^end_dt and
            not is_nil(sc.trainer_id),
        select: count(sc.id)
      )
      |> Repo.one()

    summary = [
      %{label: "Total Trainers", value: total_trainers},
      %{label: "Total Clients", value: total_clients},
      %{label: "Total Classes Taught", value: total_classes}
    ]

    total_count =
      from([gt, _u, _cc, _ct, _am] in base_query, select: count(gt.id))
      |> Repo.one()

    rows =
      from([gt, u, cc, ct, am] in base_query,
        order_by: [asc: u.name],
        select: %{
          trainer_name: u.name,
          email: u.email,
          specializations: gt.specializations,
          active_clients: cc.count,
          classes_taught: ct.count,
          attendance_marked: am.count
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        specs = row.specializations || []
        %{row | specializations: Enum.join(specs, ", ")}
      end)

    columns = [
      %{key: :trainer_name, label: "Trainer"},
      %{key: :email, label: "Email"},
      %{key: :specializations, label: "Specializations"},
      %{key: :active_clients, label: "Active Clients"},
      %{key: :classes_taught, label: "Classes Taught"},
      %{key: :attendance_marked, label: "Attendance Marked"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def trainer_overview_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = trainer_overview_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      trainer_overview_report(gym_id, start_date, end_date, opts)

    rows =
      from([gt, u, cc, ct, am] in base_query,
        order_by: [asc: u.name],
        select: %{
          trainer_name: u.name,
          email: u.email,
          specializations: gt.specializations,
          active_clients: cc.count,
          classes_taught: ct.count,
          attendance_marked: am.count
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        specs = row.specializations || []
        %{row | specializations: Enum.join(specs, ", ")}
      end)

    to_csv(summary, columns, rows)
  end

  defp trainer_overview_base_query(gym_id, start_dt, end_dt) do
    client_count_subquery =
      from(m in "gym_members",
        where: m.is_active == true,
        group_by: m.assigned_trainer_id,
        select: %{
          trainer_id: m.assigned_trainer_id,
          count: count(m.id)
        }
      )

    class_count_subquery =
      from(sc in "scheduled_classes",
        join: gb in "gym_branches",
        on: sc.branch_id == gb.id,
        where:
          gb.gym_id == uuid(gym_id) and
            sc.scheduled_at >= ^start_dt and
            sc.scheduled_at <= ^end_dt,
        group_by: sc.trainer_id,
        select: %{
          trainer_id: sc.trainer_id,
          count: count(sc.id)
        }
      )

    attendance_marked_subquery =
      from(a in "attendance_records",
        where:
          a.gym_id == uuid(gym_id) and
            a.attended_at >= ^start_dt and
            a.attended_at <= ^end_dt,
        group_by: a.marked_by_id,
        select: %{
          user_id: a.marked_by_id,
          count: count(a.id)
        }
      )

    from(gt in "gym_trainers",
      join: u in "users",
      on: gt.user_id == u.id,
      left_join: cc in subquery(client_count_subquery),
      on: cc.trainer_id == gt.id,
      left_join: ct in subquery(class_count_subquery),
      on: ct.trainer_id == gt.id,
      left_join: am in subquery(attendance_marked_subquery),
      on: am.user_id == gt.user_id,
      where: gt.gym_id == uuid(gym_id) and gt.is_active == true
    )
  end

  # ---------------------------------------------------------------------------
  # 10. trainer_client_load_report
  # ---------------------------------------------------------------------------

  @doc "Report of trainer client loads with subscription status."
  def trainer_client_load_report(gym_id, _start_date, _end_date, opts \\ []) do
    base_query = trainer_client_load_base_query(gym_id)

    # Summary: per trainer -> active / inactive
    trainer_summary =
      from([m, _mu, gt, tu] in trainer_client_load_summary_query(gym_id),
        group_by: [tu.name, m.is_active],
        select: {tu.name, m.is_active, count(m.id)}
      )
      |> Repo.all()

    summary =
      trainer_summary
      |> Enum.group_by(fn {name, _active, _count} -> name end)
      |> Enum.map(fn {name, entries} ->
        active = Enum.find_value(entries, 0, fn {_, true, c} -> c; _ -> nil end)
        inactive = Enum.find_value(entries, 0, fn {_, false, c} -> c; _ -> nil end)
        %{label: name, value: "#{active} active / #{inactive} inactive"}
      end)

    total_count =
      from([m, _mu, _gt, _tu, _ls] in base_query, select: count(m.id))
      |> Repo.one()

    rows =
      from([m, mu, _gt, tu, ls] in base_query,
        order_by: [asc: tu.name, asc: mu.name],
        select: %{
          trainer_name: tu.name,
          client_name: mu.name,
          client_status: m.is_active,
          subscription_status: ls.status,
          joined_at: m.joined_at
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | client_status: if(row.client_status, do: "Active", else: "Inactive"),
            subscription_status: row.subscription_status || "None"
        }
      end)

    columns = [
      %{key: :trainer_name, label: "Trainer"},
      %{key: :client_name, label: "Client"},
      %{key: :client_status, label: "Client Status"},
      %{key: :subscription_status, label: "Subscription Status"},
      %{key: :joined_at, label: "Joined At"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def trainer_client_load_report_csv(gym_id, start_date, end_date, opts \\ []) do
    base_query = trainer_client_load_base_query(gym_id)

    %{summary: summary, columns: columns} =
      trainer_client_load_report(gym_id, start_date, end_date, opts)

    rows =
      from([m, mu, _gt, tu, ls] in base_query,
        order_by: [asc: tu.name, asc: mu.name],
        select: %{
          trainer_name: tu.name,
          client_name: mu.name,
          client_status: m.is_active,
          subscription_status: ls.status,
          joined_at: m.joined_at
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | client_status: if(row.client_status, do: "Active", else: "Inactive"),
            subscription_status: row.subscription_status || "None"
        }
      end)

    to_csv(summary, columns, rows)
  end

  defp trainer_client_load_summary_query(gym_id) do
    from(m in "gym_members",
      join: mu in "users",
      on: m.user_id == mu.id,
      join: gt in "gym_trainers",
      on: m.assigned_trainer_id == gt.id,
      join: tu in "users",
      on: gt.user_id == tu.id,
      where:
        m.gym_id == uuid(gym_id) and
          not is_nil(m.assigned_trainer_id)
    )
  end

  defp trainer_client_load_base_query(gym_id) do
    latest_subscription_subquery =
      from(ms in "member_subscriptions",
        distinct: ms.member_id,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_id: ms.member_id,
          status: ms.status
        }
      )

    from(m in "gym_members",
      join: mu in "users",
      on: m.user_id == mu.id,
      join: gt in "gym_trainers",
      on: m.assigned_trainer_id == gt.id,
      join: tu in "users",
      on: gt.user_id == tu.id,
      left_join: ls in subquery(latest_subscription_subquery),
      on: ls.member_id == m.id,
      where:
        m.gym_id == uuid(gym_id) and
          not is_nil(m.assigned_trainer_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 11. trainer_class_performance_report
  # ---------------------------------------------------------------------------

  @doc "Trainer class performance with bookings and utilization."
  def trainer_class_performance_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = trainer_class_performance_base_query(gym_id, start_dt, end_dt)

    # Summary: per trainer -> classes, total bookings, avg utilization
    trainer_perf =
      from([sc, gt, u, cd, _gb, bc] in base_query,
        group_by: [u.name],
        select: {
          u.name,
          count(sc.id),
          coalesce(sum(bc.count), 0),
          avg(
            fragment(
              "CASE WHEN ? > 0 THEN coalesce(?, 0)::float / ? * 100 ELSE 0 END",
              cd.max_participants,
              bc.count,
              cd.max_participants
            )
          )
        }
      )
      |> Repo.all()

    summary =
      Enum.map(trainer_perf, fn {name, classes, bookings, avg_util} ->
        avg_pct = if avg_util, do: Float.round(decimal_to_float(avg_util), 1), else: 0.0
        %{label: name, value: "#{classes} classes, #{decimal_to_int(bookings)} bookings, #{avg_pct}% avg util"}
      end)

    total_count =
      from([sc, _gt, _u, _cd, _gb, _bc] in base_query, select: count(sc.id))
      |> Repo.one()

    rows =
      from([sc, _gt, u, cd, _gb, bc] in base_query,
        order_by: [asc: u.name, desc: sc.scheduled_at],
        select: %{
          trainer_name: u.name,
          class_name: cd.name,
          scheduled_date: fragment("?::date", sc.scheduled_at),
          bookings: bc.count,
          capacity: cd.max_participants,
          utilization_pct:
            fragment(
              "CASE WHEN ? > 0 THEN round(coalesce(?, 0)::numeric / ? * 100, 1) ELSE 0 END",
              cd.max_participants,
              bc.count,
              cd.max_participants
            )
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | bookings: row.bookings || 0,
            utilization_pct: decimal_to_float(row.utilization_pct)
        }
      end)

    columns = [
      %{key: :trainer_name, label: "Trainer"},
      %{key: :class_name, label: "Class"},
      %{key: :scheduled_date, label: "Date"},
      %{key: :bookings, label: "Bookings"},
      %{key: :capacity, label: "Capacity"},
      %{key: :utilization_pct, label: "Utilization %"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def trainer_class_performance_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = trainer_class_performance_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      trainer_class_performance_report(gym_id, start_date, end_date, opts)

    rows =
      from([sc, _gt, u, cd, _gb, bc] in base_query,
        order_by: [asc: u.name, desc: sc.scheduled_at],
        select: %{
          trainer_name: u.name,
          class_name: cd.name,
          scheduled_date: fragment("?::date", sc.scheduled_at),
          bookings: bc.count,
          capacity: cd.max_participants,
          utilization_pct:
            fragment(
              "CASE WHEN ? > 0 THEN round(coalesce(?, 0)::numeric / ? * 100, 1) ELSE 0 END",
              cd.max_participants,
              bc.count,
              cd.max_participants
            )
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | bookings: row.bookings || 0,
            utilization_pct: decimal_to_float(row.utilization_pct)
        }
      end)

    to_csv(summary, columns, rows)
  end

  defp trainer_class_performance_base_query(gym_id, start_dt, end_dt) do
    booking_count_subquery =
      from(cb in "class_bookings",
        where: cb.status in ^["pending", "confirmed"],
        group_by: cb.scheduled_class_id,
        select: %{
          scheduled_class_id: cb.scheduled_class_id,
          count: count(cb.id)
        }
      )

    from(sc in "scheduled_classes",
      join: gt in "gym_trainers",
      on: sc.trainer_id == gt.id,
      join: u in "users",
      on: gt.user_id == u.id,
      join: cd in "class_definitions",
      on: sc.class_definition_id == cd.id,
      join: gb in "gym_branches",
      on: sc.branch_id == gb.id,
      left_join: bc in subquery(booking_count_subquery),
      on: bc.scheduled_class_id == sc.id,
      where:
        gb.gym_id == uuid(gym_id) and
          sc.scheduled_at >= ^start_dt and
          sc.scheduled_at <= ^end_dt and
          not is_nil(sc.trainer_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 12. trainer_attendance_report
  # ---------------------------------------------------------------------------

  @doc "Attendance records for trainer's assigned clients."
  def trainer_attendance_report(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = trainer_attendance_base_query(gym_id, start_dt, end_dt)

    # Summary: per trainer -> total checkins, avg per client
    trainer_stats =
      from([a, m, _gt, tu, _mu] in base_query,
        group_by: [tu.name],
        select: {tu.name, count(a.id), count(fragment("DISTINCT ?", m.id))}
      )
      |> Repo.all()

    summary =
      Enum.map(trainer_stats, fn {name, checkins, distinct_clients} ->
        avg = if distinct_clients > 0, do: Float.round(checkins / distinct_clients, 1), else: 0.0
        %{label: name, value: "#{checkins} check-ins, #{avg} avg/client"}
      end)

    total_count =
      from([a, _m, _gt, _tu, _mu] in base_query, select: count(a.id))
      |> Repo.one()

    rows =
      from([a, _m, _gt, tu, mu] in base_query,
        order_by: [asc: tu.name, desc: a.attended_at],
        select: %{
          trainer_name: tu.name,
          client_name: mu.name,
          attended_date: fragment("?::date", a.attended_at),
          time: fragment("to_char(?, 'HH24:MI')", a.attended_at)
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :trainer_name, label: "Trainer"},
      %{key: :client_name, label: "Client"},
      %{key: :attended_date, label: "Date"},
      %{key: :time, label: "Time"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def trainer_attendance_report_csv(gym_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = trainer_attendance_base_query(gym_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      trainer_attendance_report(gym_id, start_date, end_date, opts)

    rows =
      from([a, _m, _gt, tu, mu] in base_query,
        order_by: [asc: tu.name, desc: a.attended_at],
        select: %{
          trainer_name: tu.name,
          client_name: mu.name,
          attended_date: fragment("?::date", a.attended_at),
          time: fragment("to_char(?, 'HH24:MI')", a.attended_at)
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp trainer_attendance_base_query(gym_id, start_dt, end_dt) do
    from(a in "attendance_records",
      join: m in "gym_members",
      on: a.member_id == m.id,
      join: gt in "gym_trainers",
      on: m.assigned_trainer_id == gt.id,
      join: tu in "users",
      on: gt.user_id == tu.id,
      join: mu in "users",
      on: m.user_id == mu.id,
      where:
        a.gym_id == uuid(gym_id) and
          a.attended_at >= ^start_dt and
          a.attended_at <= ^end_dt and
          not is_nil(m.assigned_trainer_id)
    )
  end

  # ===========================================================================
  # TRAINER SELF REPORTS (13-18)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # 13. my_clients_report
  # ---------------------------------------------------------------------------

  @doc "Trainer's own clients report with subscription status."
  def my_clients_report(gym_id, trainer_id, _start_date, _end_date, opts \\ []) do
    base_query = my_clients_base_query(gym_id, trainer_id)

    status_counts =
      from([m, _u, _ls] in base_query,
        group_by: m.is_active,
        select: {m.is_active, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    active = Map.get(status_counts, true, 0)
    inactive = Map.get(status_counts, false, 0)

    summary = [
      %{label: "Active", value: active},
      %{label: "Inactive", value: inactive},
      %{label: "Total", value: active + inactive}
    ]

    total_count = active + inactive

    rows =
      from([m, u, ls] in base_query,
        order_by: [asc: u.name],
        select: %{
          client_name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          subscription_status: ls.status,
          joined_at: m.joined_at
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | status: if(row.status, do: "Active", else: "Inactive"),
            subscription_status: row.subscription_status || "None"
        }
      end)

    columns = [
      %{key: :client_name, label: "Client"},
      %{key: :email, label: "Email"},
      %{key: :phone, label: "Phone"},
      %{key: :status, label: "Status"},
      %{key: :subscription_status, label: "Subscription"},
      %{key: :joined_at, label: "Joined At"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def my_clients_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    base_query = my_clients_base_query(gym_id, trainer_id)

    %{summary: summary, columns: columns} =
      my_clients_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([m, u, ls] in base_query,
        order_by: [asc: u.name],
        select: %{
          client_name: u.name,
          email: u.email,
          phone: u.phone,
          status: m.is_active,
          subscription_status: ls.status,
          joined_at: m.joined_at
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{
          row
          | status: if(row.status, do: "Active", else: "Inactive"),
            subscription_status: row.subscription_status || "None"
        }
      end)

    to_csv(summary, columns, rows)
  end

  defp my_clients_base_query(gym_id, trainer_id) do
    latest_subscription_subquery =
      from(ms in "member_subscriptions",
        distinct: ms.member_id,
        order_by: [desc: ms.inserted_at],
        select: %{
          member_id: ms.member_id,
          status: ms.status
        }
      )

    from(m in "gym_members",
      join: u in "users",
      on: m.user_id == u.id,
      left_join: ls in subquery(latest_subscription_subquery),
      on: ls.member_id == m.id,
      where:
        m.gym_id == uuid(gym_id) and
          m.assigned_trainer_id == uuid(trainer_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 14. client_attendance_report
  # ---------------------------------------------------------------------------

  @doc "Attendance report for a trainer's assigned clients."
  def client_attendance_report(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = client_attendance_base_query(gym_id, trainer_id, start_dt, end_dt)

    total_count =
      from([a, _m, _u] in base_query, select: count(a.id))
      |> Repo.one()

    days_in_range = max(Date.diff(end_date, start_date) + 1, 1)
    avg_daily = if total_count > 0, do: Float.round(total_count / days_in_range, 1), else: 0.0

    summary = [
      %{label: "Total Check-ins", value: total_count},
      %{label: "Avg Daily", value: avg_daily}
    ]

    rows =
      from([a, _m, u] in base_query,
        order_by: [desc: a.attended_at],
        select: %{
          client_name: u.name,
          attended_date: fragment("?::date", a.attended_at),
          attended_time: fragment("to_char(?, 'HH24:MI')", a.attended_at),
          notes: a.notes
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :client_name, label: "Client"},
      %{key: :attended_date, label: "Date"},
      %{key: :attended_time, label: "Time"},
      %{key: :notes, label: "Notes"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def client_attendance_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = client_attendance_base_query(gym_id, trainer_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      client_attendance_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([a, _m, u] in base_query,
        order_by: [desc: a.attended_at],
        select: %{
          client_name: u.name,
          attended_date: fragment("?::date", a.attended_at),
          attended_time: fragment("to_char(?, 'HH24:MI')", a.attended_at),
          notes: a.notes
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp client_attendance_base_query(gym_id, trainer_id, start_dt, end_dt) do
    from(a in "attendance_records",
      join: m in "gym_members",
      on: a.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      where:
        a.gym_id == uuid(gym_id) and
          m.assigned_trainer_id == uuid(trainer_id) and
          a.attended_at >= ^start_dt and
          a.attended_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 15. client_subscriptions_report
  # ---------------------------------------------------------------------------

  @doc "Subscription report for a trainer's assigned clients."
  def client_subscriptions_report(gym_id, trainer_id, _start_date, _end_date, opts \\ []) do
    base_query = client_subscriptions_base_query(gym_id, trainer_id)

    status_counts =
      from([ms, _m, _u, _sp] in base_query,
        group_by: ms.status,
        select: {ms.status, count(ms.id)}
      )
      |> Repo.all()
      |> Map.new()

    active = Map.get(status_counts, "active", 0)
    expired = Map.get(status_counts, "expired", 0)
    cancelled = Map.get(status_counts, "cancelled", 0)

    summary = [
      %{label: "Active", value: active},
      %{label: "Expired", value: expired},
      %{label: "Cancelled", value: cancelled}
    ]

    total_count = active + expired + cancelled

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [asc: u.name],
        select: %{
          client_name: u.name,
          plan_name: sp.name,
          status: ms.status,
          payment_status: ms.payment_status,
          starts_at: ms.starts_at,
          ends_at: ms.ends_at
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :client_name, label: "Client"},
      %{key: :plan_name, label: "Plan"},
      %{key: :status, label: "Status"},
      %{key: :payment_status, label: "Payment Status"},
      %{key: :starts_at, label: "Starts At"},
      %{key: :ends_at, label: "Ends At"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def client_subscriptions_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    base_query = client_subscriptions_base_query(gym_id, trainer_id)

    %{summary: summary, columns: columns} =
      client_subscriptions_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([ms, _m, u, sp] in base_query,
        order_by: [asc: u.name],
        select: %{
          client_name: u.name,
          plan_name: sp.name,
          status: ms.status,
          payment_status: ms.payment_status,
          starts_at: ms.starts_at,
          ends_at: ms.ends_at
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp client_subscriptions_base_query(gym_id, trainer_id) do
    from(ms in "member_subscriptions",
      join: m in "gym_members",
      on: ms.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      join: sp in "subscription_plans",
      on: ms.subscription_plan_id == sp.id,
      where:
        ms.gym_id == uuid(gym_id) and
          m.assigned_trainer_id == uuid(trainer_id)
    )
  end

  # ---------------------------------------------------------------------------
  # 16. workout_plans_report
  # ---------------------------------------------------------------------------

  @doc "Workout plans report for a trainer's clients."
  def workout_plans_report(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = workout_plans_base_query(gym_id, trainer_id, start_dt, end_dt)

    total_count =
      from([wp, _m, _u] in base_query, select: count(wp.id))
      |> Repo.one()

    summary = [%{label: "Total Plans", value: total_count}]

    rows =
      from([wp, _m, u] in base_query,
        order_by: [desc: wp.inserted_at],
        select: %{
          client_name: u.name,
          plan_name: wp.name,
          created_date: fragment("?::date", wp.inserted_at),
          exercises_count:
            fragment("jsonb_array_length(coalesce(?, '[]'::jsonb))", wp.exercises)
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :client_name, label: "Client"},
      %{key: :plan_name, label: "Plan Name"},
      %{key: :created_date, label: "Created Date"},
      %{key: :exercises_count, label: "Exercises"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def workout_plans_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = workout_plans_base_query(gym_id, trainer_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      workout_plans_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([wp, _m, u] in base_query,
        order_by: [desc: wp.inserted_at],
        select: %{
          client_name: u.name,
          plan_name: wp.name,
          created_date: fragment("?::date", wp.inserted_at),
          exercises_count:
            fragment("jsonb_array_length(coalesce(?, '[]'::jsonb))", wp.exercises)
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp workout_plans_base_query(gym_id, trainer_id, start_dt, end_dt) do
    from(wp in "workout_plans",
      join: m in "gym_members",
      on: wp.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      where:
        wp.gym_id == uuid(gym_id) and
          wp.trainer_id == uuid(trainer_id) and
          wp.inserted_at >= ^start_dt and
          wp.inserted_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 17. diet_plans_report
  # ---------------------------------------------------------------------------

  @doc "Diet plans report for a trainer's clients."
  def diet_plans_report(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = diet_plans_base_query(gym_id, trainer_id, start_dt, end_dt)

    total_count =
      from([dp, _m, _u] in base_query, select: count(dp.id))
      |> Repo.one()

    type_counts =
      from([dp, _m, _u] in base_query,
        group_by: dp.dietary_type,
        select: {dp.dietary_type, count(dp.id)}
      )
      |> Repo.all()

    summary =
      [%{label: "Total Plans", value: total_count}] ++
        Enum.map(type_counts, fn {dtype, count} ->
          %{label: humanize_dietary_type(dtype), value: count}
        end)

    rows =
      from([dp, _m, u] in base_query,
        order_by: [desc: dp.inserted_at],
        select: %{
          client_name: u.name,
          plan_name: dp.name,
          dietary_type: dp.dietary_type,
          calorie_target: dp.calorie_target,
          created_date: fragment("?::date", dp.inserted_at)
        }
      )
      |> paginate(opts)
      |> Repo.all()

    columns = [
      %{key: :client_name, label: "Client"},
      %{key: :plan_name, label: "Plan Name"},
      %{key: :dietary_type, label: "Dietary Type"},
      %{key: :calorie_target, label: "Calorie Target"},
      %{key: :created_date, label: "Created Date"}
    ]

    %{summary: summary, rows: rows, total_count: total_count, columns: columns}
  end

  def diet_plans_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = diet_plans_base_query(gym_id, trainer_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      diet_plans_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([dp, _m, u] in base_query,
        order_by: [desc: dp.inserted_at],
        select: %{
          client_name: u.name,
          plan_name: dp.name,
          dietary_type: dp.dietary_type,
          calorie_target: dp.calorie_target,
          created_date: fragment("?::date", dp.inserted_at)
        }
      )
      |> Repo.all()

    to_csv(summary, columns, rows)
  end

  defp diet_plans_base_query(gym_id, trainer_id, start_dt, end_dt) do
    from(dp in "diet_plans",
      join: m in "gym_members",
      on: dp.member_id == m.id,
      join: u in "users",
      on: m.user_id == u.id,
      where:
        dp.gym_id == uuid(gym_id) and
          dp.trainer_id == uuid(trainer_id) and
          dp.inserted_at >= ^start_dt and
          dp.inserted_at <= ^end_dt
    )
  end

  # ---------------------------------------------------------------------------
  # 18. my_classes_report
  # ---------------------------------------------------------------------------

  @doc "Trainer's own classes report with booking counts."
  def my_classes_report(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = my_classes_base_query(gym_id, trainer_id, start_dt, end_dt)

    total_classes =
      from([sc, _cd, _gb, _bc] in base_query, select: count(sc.id))
      |> Repo.one()

    completed =
      from([sc, _cd, _gb, _bc] in base_query,
        where: sc.status == ^"completed",
        select: count(sc.id)
      )
      |> Repo.one()

    total_bookings =
      from([_sc, _cd, _gb, bc] in base_query,
        select: coalesce(sum(bc.count), 0)
      )
      |> Repo.one()

    summary = [
      %{label: "Total Classes", value: total_classes},
      %{label: "Completed", value: completed},
      %{label: "Total Bookings", value: decimal_to_int(total_bookings)}
    ]

    rows =
      from([sc, cd, _gb, bc] in base_query,
        order_by: [desc: sc.scheduled_at],
        select: %{
          class_name: cd.name,
          scheduled_date: fragment("?::date", sc.scheduled_at),
          status: sc.status,
          bookings: bc.count,
          capacity: cd.max_participants
        }
      )
      |> paginate(opts)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | bookings: row.bookings || 0}
      end)

    columns = [
      %{key: :class_name, label: "Class"},
      %{key: :scheduled_date, label: "Date"},
      %{key: :status, label: "Status"},
      %{key: :bookings, label: "Bookings"},
      %{key: :capacity, label: "Capacity"}
    ]

    %{summary: summary, rows: rows, total_count: total_classes, columns: columns}
  end

  def my_classes_report_csv(gym_id, trainer_id, start_date, end_date, opts \\ []) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)
    base_query = my_classes_base_query(gym_id, trainer_id, start_dt, end_dt)

    %{summary: summary, columns: columns} =
      my_classes_report(gym_id, trainer_id, start_date, end_date, opts)

    rows =
      from([sc, cd, _gb, bc] in base_query,
        order_by: [desc: sc.scheduled_at],
        select: %{
          class_name: cd.name,
          scheduled_date: fragment("?::date", sc.scheduled_at),
          status: sc.status,
          bookings: bc.count,
          capacity: cd.max_participants
        }
      )
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | bookings: row.bookings || 0}
      end)

    to_csv(summary, columns, rows)
  end

  defp my_classes_base_query(gym_id, trainer_id, start_dt, end_dt) do
    booking_count_subquery =
      from(cb in "class_bookings",
        where: cb.status in ^["pending", "confirmed"],
        group_by: cb.scheduled_class_id,
        select: %{
          scheduled_class_id: cb.scheduled_class_id,
          count: count(cb.id)
        }
      )

    from(sc in "scheduled_classes",
      join: cd in "class_definitions",
      on: sc.class_definition_id == cd.id,
      join: gb in "gym_branches",
      on: sc.branch_id == gb.id,
      left_join: bc in subquery(booking_count_subquery),
      on: bc.scheduled_class_id == sc.id,
      where:
        gb.gym_id == uuid(gym_id) and
          sc.trainer_id == uuid(trainer_id) and
          sc.scheduled_at >= ^start_dt and
          sc.scheduled_at <= ^end_dt
    )
  end

  # ===========================================================================
  # PRIVATE HELPERS
  # ===========================================================================

  defp paginate(query, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page
    query |> limit(^per_page) |> offset(^offset)
  end

  defp to_start_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  defp to_end_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end

  defp to_csv(summary, columns, rows) do
    summary_lines = Enum.map(summary, fn %{label: l, value: v} -> "#{l},#{v}" end)
    header_line = Enum.map_join(columns, ",", fn %{label: l} -> "\"#{l}\"" end)

    data_lines =
      Enum.map(rows, fn row ->
        Enum.map_join(columns, ",", fn %{key: k} ->
          "\"#{to_string(Map.get(row, k, ""))}\""
        end)
      end)

    Enum.join(summary_lines ++ [""] ++ [header_line] ++ data_lines, "\n")
  end

  defp format_currency(paise) when is_integer(paise) do
    rupees = div(paise, 100)
    formatted = format_number_with_commas(rupees)
    "\u20B9#{formatted}"
  end

  defp format_currency(_), do: "\u20B90"

  defp format_number_with_commas(n) when n < 0, do: "-" <> format_number_with_commas(-n)

  defp format_number_with_commas(n) when n < 1000, do: Integer.to_string(n)

  defp format_number_with_commas(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp decimal_to_int(%Decimal{} = d), do: Decimal.to_integer(d)
  defp decimal_to_int(v) when is_integer(v), do: v
  defp decimal_to_int(v) when is_float(v), do: round(v)
  defp decimal_to_int(nil), do: 0
  defp decimal_to_int(_), do: 0

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(v) when is_float(v), do: v
  defp decimal_to_float(v) when is_integer(v), do: v / 1
  defp decimal_to_float(nil), do: 0.0
  defp decimal_to_float(_), do: 0.0

  defp humanize_dietary_type("vegetarian"), do: "Vegetarian"
  defp humanize_dietary_type("non_vegetarian"), do: "Non-Vegetarian"
  defp humanize_dietary_type("vegan"), do: "Vegan"
  defp humanize_dietary_type("eggetarian"), do: "Eggetarian"
  defp humanize_dietary_type(other), do: to_string(other)
end
